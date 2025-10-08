terraform {
  required_version = ">= 1.13.0, < 2.0.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.6.0, < 4.0.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.47.0, < 5.0.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.0, < 3.0.0"
    }

    nomad = {
      source  = "hashicorp/nomad"
      version = ">= 2.5.0, < 3.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.0, < 4.0.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.1.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
}

provider "nomad" {
  address   = "http://${azurerm_linux_virtual_machine.server[0].public_ip_address}:4646"
  region    = var.domain
  secret_id = random_uuid.nomad_mgmt_token.result

  ignore_env_vars = {
    "NOMAD_ADDR" : true,
    "NOMAD_TOKEN" : true,
    "NOMAD_CACERT" : true,
    "NOMAD_TLS_SERVER_NAME" : true,
  }
}
