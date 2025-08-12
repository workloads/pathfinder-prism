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

# Redirects output on file
# exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

#-------------------------------------------------------------------------------
# Configure and start servers
#-------------------------------------------------------------------------------

# Paths for configuration files
#-------------------------------------------------------------------------------

echo "Setup configuration PATHS"

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

echo "Retrieve IP addresses"

# Wait for network
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
    # PUBLIC_IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["frontendIpAddress"]')

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

echo "Setup Environment variables"

NOMAD_RETRY_JOIN="${retry_join}"

# nomad.hcl variables needed
NOMAD_DATACENTER="${datacenter}"
NOMAD_DOMAIN="${domain}"
NOMAD_NODE_NAME="${nomad_node_name}"
NOMAD_SERVER_COUNT="${server_count}"
NOMAD_ENCRYPTION_KEY="${nomad_encryption_key}"

NOMAD_MANAGEMENT_TOKEN="${nomad_management_token}"

# Configure and start Nomad
#-------------------------------------------------------------------------------

echo "Create Nomad configuration files"

# Copy template into Nomad configuration directory
# sudo cp $CONFIG_DIR/nomad-server.hcl $NOMAD_CONFIG_DIR/nomad.hcl

rm -f $NOMAD_CONFIG_DIR/nomad.hcl

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
# SERVER CONFIG                |
# -----------------------------+

server {
  enabled          = true
  bootstrap_expect = _NOMAD_SERVER_COUNT
  encrypt = "_NOMAD_ENCRYPTION_KEY"

  server_join {
    retry_join = [ "_NOMAD_RETRY_JOIN" ]
  }
}

ui {
  enabled = true
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

# -----------------------------+
# MONITORING CONFIG            |
# -----------------------------+

# telemetry {
#   publish_allocation_metrics = true
#   publish_node_metrics       = true
#   prometheus_metrics         = true
# }

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

# Populate the file with values from the variables
sudo sed -i "s/_NOMAD_DATACENTER/$NOMAD_DATACENTER/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_DOMAIN/$NOMAD_DOMAIN/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_NODE_NAME/$NOMAD_NODE_NAME/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_SERVER_COUNT/$NOMAD_SERVER_COUNT/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s#_NOMAD_ENCRYPTION_KEY#$NOMAD_ENCRYPTION_KEY#g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_RETRY_JOIN/$NOMAD_RETRY_JOIN/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_PUBLIC_IP_ADDRESS/$PUBLIC_IP_ADDRESS/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_PRIVATE_IP_ADDRESS/$PRIVATE_IP_ADDRESS/g" $NOMAD_CONFIG_DIR/nomad.hcl

echo "Start Nomad"

sudo systemctl enable nomad.service
sudo systemctl start nomad.service

## todo instead of sleeping check on status https://developer.hashicorp.com/nomad/api-docs/status
sleep 10

# Bootstrap Nomad
#-------------------------------------------------------------------------------

echo "Bootstrap Nomad"

# Wait for nomad servers to come up and bootstrap nomad ACL
for i in {1..12}; do
    # capture stdout and stderr
    set +e
    sleep 5
    set -x 
    
    if [ "$TLS_ENABLED" = "true" ]; then
      export NOMAD_ADDR="https://localhost:4646"
      export NOMAD_CACERT="$NOMAD_CONFIG_DIR/nomad-agent-ca.pem"
    else
      export NOMAD_ADDR="http://localhost:4646"
    fi

    OUTPUT=$(echo "$NOMAD_MANAGEMENT_TOKEN" | nomad acl bootstrap - 2>&1)
    if [ $? -ne 0 ]; then
        echo "nomad acl bootstrap: $OUTPUT"
        if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
            echo "nomad no cluster leader"
            continue
        else
            echo "nomad already bootstrapped"
            exit 0
        fi
    else 
        echo "nomad bootstrapped"
        break
    fi
    set +x 
    set -e
done

## todo instead of sleeping check on status https://developer.hashicorp.com/nomad/api-docs/status
# sleep 30