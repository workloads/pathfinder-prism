# Azure VM Password (for SSH access)
output "azure_vm_password" {
  description = "Password for Azure VMs"
  value       = random_string.vm_password.result
  sensitive   = true
}

# Nomad Server Information
output "nomad_servers" {
  description = "Azure Nomad server information"
  value = {
    count       = var.azure_server_count
    public_ips  = azurerm_linux_virtual_machine.server[*].public_ip_address
    private_ips = azurerm_linux_virtual_machine.server[*].private_ip_address
    names       = azurerm_linux_virtual_machine.server[*].name
  }
}

# Nomad Client Information
output "nomad_clients" {
  description = "Azure Nomad client information"
  value = {
    private_count      = var.azure_private_client_count
    public_count       = var.azure_public_client_count
    private_public_ips = azurerm_linux_virtual_machine.private_client[*].public_ip_address
    public_public_ips  = azurerm_linux_virtual_machine.public_client[*].public_ip_address
    private_names      = azurerm_linux_virtual_machine.private_client[*].name
    public_names       = azurerm_linux_virtual_machine.public_client[*].name
  }
}

# SSH Commands
output "ssh_commands" {
  description = "SSH commands to connect to Azure VMs"
  value = {
    servers = [
      for i, ip in azurerm_linux_virtual_machine.server[*].public_ip_address :
      "ssh ubuntu@${ip} # Server ${i}"
    ]
    private_clients = [
      for i, ip in azurerm_linux_virtual_machine.private_client[*].public_ip_address :
      "ssh ubuntu@${ip} # Private Client ${i}"
    ]
    public_clients = [
      for i, ip in azurerm_linux_virtual_machine.public_client[*].public_ip_address :
      "ssh ubuntu@${ip} # Public Client ${i}"
    ]
  }
}

# Nomad Access Information
output "nomad_access" {
  description = "Nomad access information for CLI and UI"
  value = {
    address = "http://${azurerm_linux_virtual_machine.server[0].public_ip_address}:4646"
    region  = var.domain
    ca_file = "${path.module}/certs/datacenter_ca.cert"
    token   = random_uuid.nomad_mgmt_token.result
  }
  sensitive = true
}

# TLS Certificate Information
output "tls_info" {
  description = "TLS certificate information"
  value = {
    ca_cert_file     = "${path.module}/certs/datacenter_ca.cert"
    management_token = random_uuid.nomad_mgmt_token.result
    gossip_key       = random_id.nomad_gossip_key.b64_std
  }
  sensitive = true
}

# Azure Blob Storage Information
output "azure_storage" {
  description = "Azure Blob Storage configuration"
  value = {
    storage_account_name = azurerm_storage_account.workshop_storage.name
    storage_account_key  = azurerm_storage_account.workshop_storage.primary_access_key
    connection_string    = azurerm_storage_account.workshop_storage.primary_connection_string
    containers = {
      uploads        = azurerm_storage_container.uploads.name
      processed      = azurerm_storage_container.processed.name
      knowledge_base = azurerm_storage_container.knowledge_base.name
      nomad_data     = azurerm_storage_container.nomad_data.name
    }
    managed_identity_id           = azurerm_user_assigned_identity.workshop_storage_identity.id
    managed_identity_principal_id = azurerm_user_assigned_identity.workshop_storage_identity.principal_id
  }
  sensitive = true
}

# Vault Information
output "vault_ip" {
  description = "Vault cluster information"
  value = azurerm_linux_virtual_machine.private_client_vault[0].public_ip_address
}