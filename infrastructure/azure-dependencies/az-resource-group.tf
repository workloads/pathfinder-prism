# This config creates the resource group that will contain
# all of the other resources. It needs to be created before
# anything else as the VM image is stored in it.

terraform {
  required_version = ">= 0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# NOTE: These must match the values set in /nomad/variables.hcl
locals {
  azure_resource_group_name   = "ai_dev"
  azure_location              = "eastus"
}

resource "azurerm_resource_group" "ai_dev" {
  name                        = local.azure_resource_group_name
  location                    = local.azure_location
}