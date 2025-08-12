# Vault KV-based PII Protection (Open Source Compatible)
# This file implements PII protection using Vault KV secrets engine
# Works with Vault Open Source and provides secure pattern storage

# Enable KV v2 secrets engine for PII patterns
resource "terracurl_request" "enable_kv" {
  method = "POST"
  name = "enable_kv_secrets_engine"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/sys/mounts/secret"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    type = "kv"
    options = {
      version = "2"
    }
    description = "KV Version 2 secret engine for PII patterns"
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.configure_jwt
  ]
}

# Store SSN detection pattern
resource "terracurl_request" "store_ssn_pattern" {
  method = "POST"
  name = "store_ssn_pattern"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/secret/data/pii-patterns/ssn"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    data = {
      pattern = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
      description = "Social Security Number pattern"
      risk_level = "high"
      method = "tokenize"
      prefix = "tok_ssn_"
    }
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.enable_kv
  ]
}

# Store email detection pattern
resource "terracurl_request" "store_email_pattern" {
  method = "POST"
  name = "store_email_pattern"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/secret/data/pii-patterns/email"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    data = {
      pattern = "\\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\\b"
      description = "Email address pattern"
      risk_level = "high"
      method = "tokenize"
      prefix = "tok_email_"
    }
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.enable_kv
  ]
}

# Store phone detection pattern
resource "terracurl_request" "store_phone_pattern" {
  method = "POST"
  name = "store_phone_pattern"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/secret/data/pii-patterns/phone"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    data = {
      pattern = "\\b\\d{3}-\\d{3}-\\d{4}\\b"
      description = "Phone number pattern"
      risk_level = "medium"
      method = "mask"
      mask_pattern = "***-***-****"
    }
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.enable_kv
  ]
}

# Store bank account detection pattern
resource "terracurl_request" "store_bank_pattern" {
  method = "POST"
  name = "store_bank_pattern"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/secret/data/pii-patterns/bank"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    data = {
      pattern = "\\b\\d{4}-\\d{4}-\\d{4}-\\d{4}\\b"
      description = "Bank account number pattern"
      risk_level = "medium"
      method = "mask"
      mask_pattern = "****-****-****-****"
    }
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.enable_kv
  ]
}

# Store SSN replacement strategy
resource "terracurl_request" "store_ssn_strategy" {
  method = "POST"
  name = "store_ssn_strategy"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/secret/data/pii-replacements/ssn"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    data = {
      method = "tokenize"
      prefix = "tok_ssn_"
      length = 12
      reversible = true
      description = "SSN tokenization strategy"
    }
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.enable_kv
  ]
}

# Store phone replacement strategy
resource "terracurl_request" "store_phone_strategy" {
  method = "POST"
  name = "store_phone_strategy"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/secret/data/pii-replacements/phone"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    data = {
      method = "mask"
      pattern = "***-***-****"
      reversible = false
      description = "Phone masking strategy"
    }
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.enable_kv
  ]
}

# Create policy for file-processor to access PII patterns
resource "terracurl_request" "create_file_processor_policy" {
  method = "POST"
  name = "create_file_processor_policy"
  response_codes = [200, 201, 204]
  url = "http://${local.vault_ip}:8200/v1/sys/policies/acl/file-processor"
  
  headers = {
    "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
    "Content-Type" = "application/json"
  }
  
  request_body = jsonencode({
    policy = <<EOT
# File processor policy for PII protection
path "secret/data/pii-patterns/*" {
  capabilities = ["read"]
}

path "secret/data/pii-replacements/*" {
  capabilities = ["read"]
}

path "secret/metadata/pii-patterns/*" {
  capabilities = ["read"]
}

path "secret/metadata/pii-replacements/*" {
  capabilities = ["read"]
}
EOT
  })
  
  max_retry = 3
  retry_interval = 5
  
  depends_on = [
    terracurl_request.store_ssn_pattern,
    terracurl_request.store_email_pattern,
    terracurl_request.store_phone_pattern,
    terracurl_request.store_bank_pattern,
    terracurl_request.store_ssn_strategy,
    terracurl_request.store_phone_strategy
  ]
}
