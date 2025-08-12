terraform {
  required_version = ">= 0.12"
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "2.3.1"
    }
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "nomad" {
  address   = "http://${local.nomad_servers_public_ip}:4646"
  region    = var.domain
  secret_id = var.nomad_mgmt_token
  ignore_env_vars = {
    "NOMAD_ADDR" : true,
    "NOMAD_TOKEN" : true,
    "NOMAD_CACERT" : true,
    "NOMAD_TLS_SERVER_NAME" : true,
  }
}