# Vault Transform Engine Configuration (Enterprise Feature)
# This file contains the Transform Engine setup for PII protection
# Comment out this entire file when using the KV-based approach

# Enable Vault Transform Engine for PII protection
# resource "terracurl_request" "mount_transform" {
#   method = "POST"
#   name = "mount_transform_engine"
#   response_codes = [200, 201, 204]
#   url = "http://${local.vault_ip}:8200/v1/sys/mounts/ai_data_transform"
#   
#   headers = {
#     "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
#     "Content-Type" = "application/json"
#   }
#   
#   request_body = jsonencode({
#     type = "transform"
#   })
#   
#   max_retry = 3
#   retry_interval = 5
#   
#   depends_on = [
#     terracurl_request.configure_jwt
#   ]
# }

# Create PII detection alphabet for tokenization
# resource "terracurl_request" "create_alphabet" {
#   method = "POST"
#   name = "create_pii_alphabet"
#   response_codes = [200, 201, 204]
#   url = "http://${local.vault_ip}:8200/v1/ai_data_transform/alphabet/pii-alphabet"
#   
#   headers = {
#     "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
#     "Content-Type" = "application/json"
#   }
#   
#   request_body = jsonencode({
#     alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
#   })
#   
#   max_retry = 3
#   retry_interval = 5
#   
#   depends_on = [
#     terracurl_request.mount_transform
#   ]
# }

# Create PII detection template for tokenization (SSN, email)
# resource "terracurl_request" "create_tokenize_template" {
#   method = "POST"
#   name = "create_pii_tokenize_template"
#   response_codes = [200, 201, 204]
#   url = "http://${local.vault_ip}:8200/v1/ai_data_transform/template/pii-tokenize"
#   
#   headers = {
#     "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
#     "Content-Type" = "application/json"
#   }
#   
#   request_body = jsonencode({
#     type = "regex"
#     pattern = "(\\d{3}-\\d{2}-\\d{4})|([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})"
#     alphabet = "pii-alphabet"
#   })
#   
#   max_retry = 3
#   retry_interval = 5
#   
#   depends_on = [
#     terracurl_request.create_alphabet
#   ]
# }

# Create PII detection template for masking (phone, bank account)
# resource "terracurl_request" "create_mask_template" {
#   method = "POST"
#   name = "create_pii_mask_template"
#   response_codes = [200, 201, 204]
#   url = "http://${local.vault_ip}:8200/v1/ai_data_transform/template/pii-mask"
#   
#   headers = {
#     "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
#     "Content-Type" = "application/json"
#   }
#   
#   request_body = jsonencode({
#     type = "regex"
#     pattern = "(\\d{3}-\\d{3}-\\d{4})|(\\d{4}-\\d{4}-\\d{4}-\\d{4})"
#     alphabet = "pii-alphabet"
#   })
#   
#   max_retry = 3
#   retry_interval = 5
#   
#   depends_on = [
#     terracurl_request.create_alphabet
#   ]
# }

# Create transform role for file-processor with both transformations
# resource "terracurl_request" "create_role" {
#   method = "POST"
#   name = "create_file_processor_role"
#   response_codes = [200, 201, 204]
#   url = "http://${local.vault_ip}:8200/v1/ai_data_transform/role/file-processor"
#   
#   headers = {
#     "X-Vault-Token" = jsondecode(terracurl_request.vault_init.response).root_token
#     "Content-Type" = "application/json"
#   }
#   
#   request_body = jsonencode({
#     transformations = ["pii-tokenize", "pii-mask"]
#   })
#   
#   max_retry = 3
#   retry_interval = 5
#   
#   depends_on = [
#     terracurl_request.create_tokenize_template,
#     terracurl_request.create_mask_template
#   ]
# }
