
# Vault Information
output "vault" {
  description = "Vault cluster information"
  value = {
    ui_url = "http://${local.vault_ip}:8200"
    token = jsondecode(terracurl_request.vault_init.response).root_token
    namespace = "vault-cluster"
  }
}