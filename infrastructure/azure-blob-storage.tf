# Azure Blob Storage Configuration for AI Pipeline Workshop

# Storage Account for workshop data
resource "azurerm_storage_account" "workshop_storage" {
  name                     = random_string.storage_account_suffix.result
  resource_group_name      = data.azurerm_resource_group.ai_dev.name
  location                 = var.azure_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Enable blob public access for workshop purposes
  allow_nested_items_to_be_public = true

  tags = {
    Environment = "workshop"
    Purpose     = "ai-pipeline"
  }
}

# Random suffix for storage account name uniqueness
resource "random_string" "storage_account_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Storage containers for different data types
resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.workshop_storage.name 
  container_access_type = "blob"
}

resource "azurerm_storage_container" "processed" {
  name                  = "processed"
  storage_account_name  = azurerm_storage_account.workshop_storage.name 
  container_access_type = "blob"
}

resource "azurerm_storage_container" "knowledge_base" {
  name                  = "knowledge-base"
  storage_account_name  = azurerm_storage_account.workshop_storage.name 
  container_access_type = "blob"
}

resource "azurerm_storage_container" "nomad_data" {
  name                  = "nomad-data"
  storage_account_name  = azurerm_storage_account.workshop_storage.name 
  container_access_type = "blob"
}

# User-assigned managed identity for secure storage access
resource "azurerm_user_assigned_identity" "workshop_storage_identity" {
  name                = "${local.prefix}-workshop-storage-identity"
  resource_group_name = data.azurerm_resource_group.ai_dev.name
  location            = var.azure_location
}

# Role assignment for storage account access
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.workshop_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workshop_storage_identity.principal_id
}

# Role assignment for storage account management
resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_storage_account.workshop_storage.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_user_assigned_identity.workshop_storage_identity.principal_id
} 