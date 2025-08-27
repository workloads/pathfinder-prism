# Used to define datacenter and Nomad region
variable "domain" {
  description = "Domain used to deploy Nomad and to generate TLS certificates."
  default     = "global"
}

data "terraform_remote_state" "nomad_infrastructure" {
  backend = "local"
  config = {
    path = "${path.module}/../infrastructure/terraform.tfstate"
  }
}

locals {
  nomad_servers_public_ip = data.terraform_remote_state.nomad_infrastructure.outputs.nomad_servers.public_ips[0]
  vault_ip = data.terraform_remote_state.nomad_infrastructure.outputs.vault_ip
  nomad_mgmt_token = data.terraform_remote_state.nomad_infrastructure.outputs.nomad_access.token
}