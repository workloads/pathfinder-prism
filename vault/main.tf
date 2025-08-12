# resource "hcp_hvn" "ai_dev" {
#   hvn_id         = replace(var.name_prefix, "_", "-")
#   cloud_provider = "azure"
#   region         = var.azure_location
#   cidr_block     = "10.0.0.0/20"
# }
 
# resource "hcp_vault_cluster" "ai_dev" {
#   cluster_id      = replace(var.name_prefix, "_", "-")
#   hvn_id          = hcp_hvn.ai_dev.hvn_id
#   tier            = "dev"
#   public_endpoint = true
# }
 
# resource "hcp_vault_cluster_admin_token" "ai_dev" {
#   cluster_id = hcp_vault_cluster.ai_dev.cluster_id
# }
 
# resource "vault_mount" "transform_ai_dev" {
#   path = "transform/${replace(var.name_prefix, "_", "-")}"
#   type = "transform"
# }


# Vault deployment configuration for Nomad cluster
# This file deploys Vault into the existing Nomad infrastructure

# Create Vault namespace in Nomad
resource "nomad_namespace" "vault" {
  name        = "vault-cluster"
  description = "Vault servers namespace for secret management"
}

# Deploy Vault cluster
resource "nomad_job" "vault" {
  jobspec = file("${path.module}/../jobs/vault.nomad.hcl")
  
  depends_on = [
    nomad_namespace.vault
  ]
}

# Initialize Vault after deployment
resource "terracurl_request" "vault_init" {
  method         = "POST"
  name           = "vault_init"
  response_codes = [200]
  url            = "http://${local.vault_ip}:8200/v1/sys/init"

  request_body = <<EOF
{
  "secret_shares": 1,
  "secret_threshold": 1
}
EOF
  
  max_retry      = 7
  retry_interval = 10

  depends_on = [
    nomad_job.vault
  ]
}

# Store unseal keys in Nomad variables
resource "nomad_variable" "vault_unseal_keys" {
  path      = "nomad/jobs/vault-unsealer"
  namespace = "vault-cluster"

  items = {
    key1 = jsondecode(terracurl_request.vault_init.response).keys[0]
  }

  depends_on = [
    terracurl_request.vault_init
  ]
}

# Deploy Vault unsealer for automatic unsealing
resource "nomad_job" "vault_unsealer" {
  jobspec = file("${path.module}/../jobs/vault-unsealer.nomad.hcl")
  
  depends_on = [
    nomad_namespace.vault,
    nomad_variable.vault_unseal_keys,
    nomad_job.vault
  ]
}

# Add delay before enabling JWT auth
resource "null_resource" "vault_init_delay" {
  provisioner "local-exec" {
    command = "sleep 30"
  }

  depends_on = [
    nomad_job.vault_unsealer
  ]
}

# Enable JWT auth method in Vault for Nomad workload identities
resource "terracurl_request" "enable_jwt" {
  method = "POST"
  name   = "enable_jwt"
  response_codes = [
    200,
    201,
    204
  ]
  url = "http://${local.vault_ip}:8200/v1/sys/auth/jwt"

  headers = {
    X-Vault-Token = jsondecode(terracurl_request.vault_init.response).root_token
  }

  request_body = <<EOF
{
  "type": "jwt",
  "description": "JWT auth method for Nomad workload identities"
}
EOF

  destroy_url    = "http://${local.vault_ip}:8200/v1/sys/auth/jwt"
  destroy_method = "DELETE"

  depends_on = [
    nomad_job.vault_unsealer,
    null_resource.vault_init_delay
  ]
}

# Configure JWT authentication for Nomad integration
resource "terracurl_request" "configure_jwt" {
  method = "POST"
  name   = "configure_jwt"
  response_codes = [
    200,
    201,
    204
  ]
  url = "http://${local.vault_ip}:8200/v1/auth/jwt/config"
  
  headers = {
    X-Vault-Token = jsondecode(terracurl_request.vault_init.response).root_token
  }
  
  request_body = <<EOF
{
  "jwks_url": "http://${local.nomad_servers_public_ip}:4646/.well-known/jwks.json",
  "bound_issuer": "http://${local.nomad_servers_public_ip}:4646"
}
EOF

  destroy_method = "DELETE"
  destroy_response_codes = [
    200,
    201,
    204
  ]
  destroy_url = "http://${local.vault_ip}:8200/auth/jwt/role/nomad"

  depends_on = [
    nomad_job.vault_unsealer,
    terracurl_request.enable_jwt
  ]
}

# PII Protection Configuration
# 
# This file now focuses on core Vault setup (JWT auth, etc.)
# PII protection is implemented in separate files:
#
# - transform_engine.tf: Enterprise Transform Engine (commented out)
# - protect_pii.tf: Open Source KV-based PII protection (active)
#
# To switch between approaches:
# 1. Comment out protect_pii.tf and uncomment transform_engine.tf for Enterprise
# 2. Comment out transform_engine.tf and uncomment protect_pii.tf for Open Source
