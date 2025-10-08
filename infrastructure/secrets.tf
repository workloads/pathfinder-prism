
#-------------------------------------------------------------------------------
# GOSSIP ENCRYPTION KEYS
#-------------------------------------------------------------------------------

# Gossip encryption keys used to encrypt traffic for Nomad servers
resource "random_id" "nomad_gossip_key" {
  byte_length = 32
}

# SSH key for Azure VMs
resource "tls_private_key" "azure_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save SSH private key to file
resource "local_file" "azure_ssh_key" {
  content  = tls_private_key.azure_ssh_key.private_key_pem
  filename = "${path.module}/certs/azure_ssh_key"

  file_permission = "0600"
}

#-------------------------------------------------------------------------------
# TLS certificates for Nomad agents
#-------------------------------------------------------------------------------

# Common CA key
resource "tls_private_key" "datacenter_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Common CA Certificate
resource "tls_self_signed_cert" "datacenter_ca" {
  private_key_pem = tls_private_key.datacenter_ca.private_key_pem

  subject {
    country             = "US"
    province            = "CA"
    locality            = "San Francisco/street=101 Second Street/postalCode=9410"
    organization        = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name         = "ca.${var.datacenter}.${var.domain}"
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "crl_signing",
  ]
}

# Save CA certificate locally
resource "local_file" "ca_cert" {
  content  = tls_self_signed_cert.datacenter_ca.cert_pem
  filename = "${path.module}/certs/datacenter_ca.cert"
}

#-------------------------------------------------------------------------------
# MANAGEMENT TOKEN
#-------------------------------------------------------------------------------

resource "random_uuid" "nomad_mgmt_token" {
}

#-------------------------------------------------------------------------------
# ACL Tokens for Nomad cluster
#-------------------------------------------------------------------------------

# Nomad token for UI access
resource "nomad_acl_policy" "nomad_user_policy" {
  name        = "nomad-user"
  description = "Submit jobs to the environment."

  # Wait for all servers to be created before creating ACL resources
  depends_on = [azurerm_linux_virtual_machine.server, azurerm_public_ip.server_public_ip]

  rules_hcl = <<EOT
agent { 
    policy = "read"
} 

node { 
    policy = "read" 
} 

namespace "*" { 
    policy = "read" 
    capabilities = ["submit-job", "dispatch-job", "read-logs", "read-fs", "alloc-exec"]
}
EOT
}

resource "nomad_acl_token" "nomad_user_token" {
  name     = "nomad-user-token"
  type     = "client"
  policies = ["nomad-user"]
  global   = true

  # Wait for the policy to be created first
  depends_on = [nomad_acl_policy.nomad_user_policy]
}

# Azure private client keys
resource "tls_private_key" "azure_client_key" {
  count       = var.azure_private_client_count
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Azure private client CSR
resource "tls_cert_request" "azure_client_csr" {
  count           = var.azure_private_client_count
  private_key_pem = element(tls_private_key.azure_client_key.*.private_key_pem, count.index)

  subject {
    country             = "US"
    province            = "CA"
    locality            = "San Francisco/street=101 Second Street/postalCode=9410"
    organization        = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name         = "client-${count.index}.${var.datacenter}.${var.domain}"
  }

  dns_names = [
    "client.${var.datacenter}.${var.domain}",
    "client-${count.index}.${var.datacenter}.${var.domain}",
    "nomad-client-${count.index}.${var.datacenter}.${var.domain}",
    "client.global.nomad",
    "localhost"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]
}

# Azure private client certs
resource "tls_locally_signed_cert" "azure_client_cert" {
  count            = var.azure_private_client_count
  cert_request_pem = element(tls_cert_request.azure_client_csr.*.cert_request_pem, count.index)

  ca_private_key_pem = tls_private_key.datacenter_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.datacenter_ca.cert_pem

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}


# Azure public client keys
resource "tls_private_key" "azure_public_client_key" {
  count       = var.azure_public_client_count
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Azure public client CSR
resource "tls_cert_request" "azure_public_client_csr" {
  count           = var.azure_public_client_count
  private_key_pem = element(tls_private_key.azure_public_client_key.*.private_key_pem, count.index)

  subject {
    country             = "US"
    province            = "CA"
    locality            = "San Francisco/street=101 Second Street/postalCode=9410"
    organization        = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name         = "client-${count.index}.${var.datacenter}.${var.domain}"
  }

  dns_names = [
    "client.${var.datacenter}.${var.domain}",
    "client-${count.index}.${var.datacenter}.${var.domain}",
    "nomad-client-${count.index}.${var.datacenter}.${var.domain}",
    "client.global.nomad",
    "localhost"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]
}

# Azure public client certs
resource "tls_locally_signed_cert" "azure_public_client_cert" {
  count            = var.azure_public_client_count
  cert_request_pem = element(tls_cert_request.azure_public_client_csr.*.cert_request_pem, count.index)

  ca_private_key_pem = tls_private_key.datacenter_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.datacenter_ca.cert_pem

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

# Azure server keys
resource "tls_private_key" "azure_server_key" {
  count       = var.azure_server_count
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Azure server CSR
resource "tls_cert_request" "azure_server_csr" {
  count           = var.azure_server_count
  private_key_pem = element(tls_private_key.azure_server_key.*.private_key_pem, count.index)

  subject {
    country             = "US"
    province            = "CA"
    locality            = "San Francisco/street=101 Second Street/postalCode=9410"
    organization        = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name         = "server-${count.index}.${var.datacenter}.${var.domain}"
  }

  dns_names = [
    "nomad.${var.datacenter}.${var.domain}",
    "server.${var.datacenter}.${var.domain}",
    "server-${count.index}.${var.datacenter}.${var.domain}",
    "nomad-server-${count.index}.${var.datacenter}.${var.domain}",
    "nomad.service.${var.datacenter}.${var.domain}",
    "server.global.nomad",
    "localhost"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]
}

# Azure server certs
resource "tls_locally_signed_cert" "azure_server_cert" {
  count            = var.azure_server_count
  cert_request_pem = element(tls_cert_request.azure_server_csr.*.cert_request_pem, count.index)

  ca_private_key_pem = tls_private_key.datacenter_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.datacenter_ca.cert_pem

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}
