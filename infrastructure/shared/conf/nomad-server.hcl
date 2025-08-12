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
