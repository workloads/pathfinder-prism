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
  }
  server_join {
    retry_join = [ "_NOMAD_RETRY_JOIN" ]
  }
  node_pool = "_NODE_POOL"
}

# -----------------------------+
# NETWORKING CONFIG            |
# -----------------------------+

bind_addr = "0.0.0.0"

advertise {
  http = "_PUBLIC_IP_ADDRESS:4646"
  rpc  = "_PUBLIC_IP_ADDRESS:4647"
  serf = "_PUBLIC_IP_ADDRESS:4648"
}

# -----------------------------+
# MONITORING CONFIG            |
# -----------------------------+

# telemetry {
#   publish_allocation_metrics = true
#   publish_node_metrics       = true
#   prometheus_metrics         = true
# }

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

# ACL Configuration              
# -----------------------------

acl {
  enabled = true
}
