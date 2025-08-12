# -----------------------------------
# AZURE VARIABLES
# -----------------------------------

azure_location = "eastus"

# azure_resource_group_name must match the value for name_prefix
# in /nomad/variables.tf and in /azure-dependencies/az-resource-group.tf
azure_resource_group_name = "ai_dev"

# Default values:
azure_server_instance_type         = "Standard_B2s"
azure_server_count                 = "3"
azure_private_client_instance_type = "Standard_B4ms"
azure_private_client_count         = "0"
azure_public_client_instance_type  = "Standard_B4ms"
azure_public_client_count          = "2"
azure_allowlist_ip                 = "0.0.0.0/0"

# -----------------------------------
# VAULT VARIABLES
# -----------------------------------

# Enable Vault deployment in Nomad cluster
vault_enabled = true
azure_vault_instance_type = "Standard_B2s"
azure_vault_client_count = "1"