# A prefix to start resource names
locals {
  prefix = "${var.name_prefix}-${random_string.suffix.result}"
}

# Prefix for resource names
variable "name_prefix" {
  description = "The prefix used for all resources in this plan"
  default     = "techxchange"
}

# Random suffix for resource naming and AWS cloud auto-join
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Used to define datacenter and Nomad region
variable "domain" {
  description = "Domain used to deploy Nomad and to generate TLS certificates."
  default     = "global"
}

# Used to define Nomad domain
variable "datacenter" {
  description = "Datacenter used to deploy Nomad and to generate TLS certificates."
  default     = "dc1"
}

variable "allowlist_ip" {
  description = "IP range to allow access for security groups (set 0.0.0.0/0 for no restriction)"
  default     = "0.0.0.0/0"
}

### Azure variables

variable "azure_location" {
  description = "The Azure region to deploy to."
  default     = "eastus"
}

variable "azure_resource_group_name" {
  description = "The Azure resource group name to use."
  default     = "techxchange"
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "azure_allowlist_ip" {
  description = "IP to allow access for the security groups (set 0.0.0.0/0 for world)"
  default     = "0.0.0.0/0"
}

variable "azure_vault_instance_type" {
  description = "The Azure VM type to use for Vault (private) clients."
  default     = "Standard_B4ms"
}

variable "azure_private_client_instance_type" {
  description = "The Azure VM type to use for private clients."
  default     = "Standard_B4ms"
}

variable "azure_public_client_instance_type" {
  description = "The Azure VM type to use for public clients."
  default     = "Standard_B2s"
}

variable "azure_private_client_count" {
  description = "The number of private clients to provision."
  default     = "1"
}

variable "azure_vault_client_count" {
  description = "The number of Vault (private) clients to provision."
  default     = "1"
}

variable "azure_public_client_count" {
  description = "The number of publicly accessible clients to provision."
  default     = "1"
}

variable "azure_server_count" {
  description = "The number of Azure Nomad server nodes to provision."
  default     = 3
}

variable "azure_server_instance_type" {
  description = "The Azure VM type to use for servers."
  default     = "Standard_B2s"
}

# Vault configuration variables
variable "vault_enabled" {
  description = "Whether to deploy Vault into the Nomad cluster"
  type        = bool
  default     = true
}

variable "vault_instance_type" {
  description = "Azure VM type for Vault nodes (uses server instance type by default)"
  type        = string
  default     = null
}
