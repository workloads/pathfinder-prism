#!/bin/bash

# --- BEGIN SETUP.SH --- #

set -e

# Disable interactive apt prompts
export DEBIAN_FRONTEND="noninteractive"

mkdir -p /ops/shared/conf

CONFIGDIR=/ops/shared/conf
NOMADVERSION=1.10.1

sudo apt-get update && sudo apt-get install -y software-properties-common

sudo add-apt-repository universe && sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux
sudo apt-get clean


# Disable the firewall

sudo ufw disable || echo "ufw not installed"

# Docker
# distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
sudo apt-get install -y apt-transport-https ca-certificates gnupg2

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt-get update
sudo apt-get install -y docker-ce

# Java
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update 
sudo apt-get install -y openjdk-8-jdk
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")


# Install HashiCorp Apt Repository
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Nomad package
sudo apt-get update && sudo apt-get -y install nomad=$NOMADVERSION*

# --- END SETUP.SH --- #

# exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

#-------------------------------------------------------------------------------
# Configure and start clients
#-------------------------------------------------------------------------------

# Paths for configuration files
#-------------------------------------------------------------------------------

CONFIG_DIR=/ops/shared/conf
NOMAD_CONFIG_DIR=/etc/nomad.d

HOME_DIR=ubuntu

# Retrieve certificates (optional)
#-------------------------------------------------------------------------------

TLS_ENABLED="${tls_enabled}"

if [ "$TLS_ENABLED" = "true" ] && [ ! -z "${ca_certificate}" ] && [ ! -z "${agent_certificate}" ] && [ ! -z "${agent_key}" ]; then
  echo "Create TLS certificate files"

  echo "${ca_certificate}"    | base64 -d | zcat > /tmp/agent-ca.pem
  echo "${agent_certificate}" | base64 -d | zcat > /tmp/agent.pem
  echo "${agent_key}"         | base64 -d | zcat > /tmp/agent-key.pem

  sudo cp /tmp/agent-ca.pem $NOMAD_CONFIG_DIR/nomad-agent-ca.pem
  sudo cp /tmp/agent.pem $NOMAD_CONFIG_DIR/nomad-agent.pem
  sudo cp /tmp/agent-key.pem $NOMAD_CONFIG_DIR/nomad-agent-key.pem
else
  echo "TLS disabled or certificates not provided, running without TLS"
  TLS_ENABLED=false
fi

# IP addresses
#-------------------------------------------------------------------------------

# Wait for network
## todo test if this value is not too big
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=`ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'`

CLOUD="${cloud_env}"

# Get IP from metadata service
case $CLOUD in
  aws)
    echo "CLOUD_ENV: aws"
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    PUBLIC_IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
    ;;
  gce)
    echo "CLOUD_ENV: gce"
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    PUBLIC_IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
    ;;
  azure)
    echo "CLOUD_ENV: azure"
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    # PUBLIC_IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["publicIpAddress"]')
    
    # Standard SKU public IPs aren't in the instance metadata but rather in the loadbalancer
    PUBLIC_IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/loadbalancer?api-version=2020-10-01 | jq -r '.loadbalancer.publicIpAddresses[0].frontendIpAddress')
    PRIVATE_IP_ADDRESS=$IP_ADDRESS
    ;;
  *)
    echo "CLOUD_ENV: not set"
    ;;
esac

# Environment variables
#-------------------------------------------------------------------------------

NOMAD_RETRY_JOIN="${retry_join}"

# nomad.hcl variables needed
NOMAD_DATACENTER="${datacenter}"
NOMAD_DOMAIN="${domain}"
NOMAD_NODE_NAME="${nomad_node_name}"
NOMAD_AGENT_META="${nomad_agent_meta}"
NOMAD_CLIENT_NODE_POOL="${node_pool}"

# Debug: Print variables for troubleshooting
echo "Debug: NOMAD_DATACENTER=$NOMAD_DATACENTER"
echo "Debug: NOMAD_DOMAIN=$NOMAD_DOMAIN"
echo "Debug: NOMAD_NODE_NAME=$NOMAD_NODE_NAME"
echo "Debug: NOMAD_AGENT_META=$NOMAD_AGENT_META"
echo "Debug: NOMAD_RETRY_JOIN=$NOMAD_RETRY_JOIN"
echo "Debug: NOMAD_CLIENT_NODE_POOL=$NOMAD_CLIENT_NODE_POOL"
echo "Debug: PUBLIC_IP_ADDRESS=$PUBLIC_IP_ADDRESS"
echo "Debug: PRIVATE_IP_ADDRESS=$PRIVATE_IP_ADDRESS"

# Install Nomad prerequisites
#-------------------------------------------------------------------------------

# Install and link CNI Plugins to support Consul Connect-Enabled jobs

export ARCH_CNI=$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)
export CNI_PLUGIN_VERSION=v1.5.1
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGIN_VERSION/cni-plugins-linux-$ARCH_CNI-$CNI_PLUGIN_VERSION".tgz && \
  sudo mkdir -p /opt/cni/bin && \
  sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

# Configure and start Nomad
#-------------------------------------------------------------------------------

# Copy template into Nomad configuration directory
# sudo cp $CONFIG_DIR/nomad-client.hcl $NOMAD_CONFIG_DIR/nomad.hcl

rm -f $NOMAD_CONFIG_DIR/nomad.hcl

# Create Vault directory.
mkdir -p /etc/vault.d

# set -x 

# Create nomad agent config file
tee $NOMAD_CONFIG_DIR/nomad.hcl <<EOF
# -----------------------------+
# BASE CONFIG                  |
# -----------------------------+

datacenter = "_NOMAD_DATACENTER"
region = "_NOMAD_DOMAIN"

# Nomad node name
name = "_NOMAD_NODE_NAME"

# Data Persistence
data_dir = "/opt/nomad"

# Logging
log_level = "INFO"
enable_syslog = false
enable_debug = false

# -----------------------------+
# CLIENT CONFIG                |
# -----------------------------+

client {
  enabled = true
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
  meta {
    _NOMAD_AGENT_META
    externalAddress = "_PUBLIC_IP_ADDRESS"
  }
  server_join {
    retry_join = [ "_NOMAD_RETRY_JOIN" ]
  }
  node_pool = "_NODE_POOL"
  
  host_volume "vault_vol" {
    path      = "/etc/vault.d"
    read_only = false
  }
}

# -----------------------------+
# SERVER CONFIG (DISABLED)     |
# -----------------------------+

server {
  enabled = false
}

# -----------------------------+
# NETWORKING CONFIG            |
# -----------------------------+

bind_addr = "0.0.0.0"

advertise {
  http = "_PUBLIC_IP_ADDRESS:4646"
  rpc  = "_PRIVATE_IP_ADDRESS:4647"
  serf = "_PRIVATE_IP_ADDRESS:4648"
}

# ACL Configuration              
# -----------------------------

acl {
  enabled = true
}
EOF

# Add TLS configuration if enabled
if [ "$TLS_ENABLED" = "true" ]; then
cat >> $NOMAD_CONFIG_DIR/nomad.hcl <<EOF

# TLS Encryption              
# -----------------------------

tls {
  http      = true
  rpc       = true

  ca_file   = "/etc/nomad.d/nomad-agent-ca.pem"
  cert_file = "/etc/nomad.d/nomad-agent.pem"
  key_file  = "/etc/nomad.d/nomad-agent-key.pem"

  verify_server_hostname = true
}
EOF
fi

# Populate the file with values from the variables using a more robust approach
# Use perl for better handling of special characters in variables
sudo perl -pi -e "s/_NOMAD_DATACENTER/$NOMAD_DATACENTER/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo perl -pi -e "s/_NOMAD_DOMAIN/$NOMAD_DOMAIN/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo perl -pi -e "s/_NOMAD_NODE_NAME/$NOMAD_NODE_NAME/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo perl -pi -e "s/_PUBLIC_IP_ADDRESS/$PUBLIC_IP_ADDRESS/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo perl -pi -e "s/_PRIVATE_IP_ADDRESS/$PRIVATE_IP_ADDRESS/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo perl -pi -e "s/_NODE_POOL/$NOMAD_CLIENT_NODE_POOL/g" $NOMAD_CONFIG_DIR/nomad.hcl

# Handle the meta block separately to ensure proper HCL syntax
# Replace the _NOMAD_AGENT_META placeholder with properly formatted meta values
sudo perl -pi -e "s/_NOMAD_AGENT_META/$NOMAD_AGENT_META/g" $NOMAD_CONFIG_DIR/nomad.hcl

# Handle retry_join like the server script - simple direct substitution
sudo sed -i "s/_NOMAD_RETRY_JOIN/$NOMAD_RETRY_JOIN/g" $NOMAD_CONFIG_DIR/nomad.hcl

# Fix the meta block syntax by ensuring values are properly quoted
# This handles cases where the meta values might not be properly quoted
sudo sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\) = \([^",][^,]*\)/\1 = "\2"/g' $NOMAD_CONFIG_DIR/nomad.hcl

# Fix boolean values that shouldn't be quoted
sudo sed -i 's/enabled = "true"/enabled = true/g' $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i 's/enabled = "false"/enabled = false/g' $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i 's/enable_syslog = "false"/enable_syslog = false/g' $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i 's/enable_debug = "false"/enable_debug = false/g' $NOMAD_CONFIG_DIR/nomad.hcl

# Fix the meta block specifically for the key=value format
sudo sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\)=\([^,]*\)/\1 = "\2"/g' $NOMAD_CONFIG_DIR/nomad.hcl

# Fix meta block comma spacing
sudo sed -i 's/\([^,]*\)",\([a-zA-Z_][a-zA-Z0-9_]*\)/\1", \2/g' $NOMAD_CONFIG_DIR/nomad.hcl

# Fix retry_join specific issues for Azure provider
# Fix the opening bracket issue - remove extra quote and space
sudo sed -i 's/retry_join = "\[ /retry_join = [ /g' $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i 's/retry_join = "\[/retry_join = [/g' $NOMAD_CONFIG_DIR/nomad.hcl

# Fix the provider syntax issue - remove space and extra quote
sudo sed -i 's/provider = "azure/provider=azure/g' $NOMAD_CONFIG_DIR/nomad.hcl

# Fix the closing bracket and quote issues - remove extra quote
sudo sed -i 's/ \]"$/ ]/g' $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i 's/\]"$/]/g' $NOMAD_CONFIG_DIR/nomad.hcl

# Additional fix for retry_join array formatting - remove any extra quotes
# sudo sed -i 's/retry_join = \[ "\([^"]*\)" \]/retry_join = [ "\1" ]/g' $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i 's/""$//g' $NOMAD_CONFIG_DIR/nomad.hcl

# Debug: Show the final configuration
echo "Debug: Final nomad.hcl configuration:"
sudo cat $NOMAD_CONFIG_DIR/nomad.hcl

# Validate that all required variables were substituted
echo "Validating configuration..."
if grep -q "_NOMAD_" $NOMAD_CONFIG_DIR/nomad.hcl; then
    echo "ERROR: Some placeholder values were not replaced!"
    grep "_NOMAD_" $NOMAD_CONFIG_DIR/nomad.hcl
    exit 1
fi

if grep -q "_PUBLIC_IP_ADDRESS\|_PRIVATE_IP_ADDRESS\|_NODE_POOL" $NOMAD_CONFIG_DIR/nomad.hcl; then
    echo "ERROR: Some IP address or node pool placeholders were not replaced!"
    grep "_PUBLIC_IP_ADDRESS\|_PRIVATE_IP_ADDRESS\|_NODE_POOL" $NOMAD_CONFIG_DIR/nomad.hcl
    exit 1
fi

echo "Configuration validation passed!"

# Test the configuration syntax before starting
# echo "Testing Nomad configuration syntax..."
# if ! sudo nomad agent -config $NOMAD_CONFIG_DIR/nomad.hcl -dev -dry; then
#     echo "ERROR: Nomad configuration syntax is invalid!"
#     exit 1
# fi

# echo "Nomad configuration syntax is valid!"

set +x 

sudo systemctl enable nomad.service
sudo systemctl start nomad.service