# Used to define datacenter and Nomad region
variable "domain" {
  description = "Domain used to deploy Nomad and to generate TLS certificates."
  default     = "global"
}

variable "nomad_mgmt_token" {
  description = "Nomad management token"
  type        = string
  default     = "73f71dd1-17de-e2ff-d28c-6daa07e7390c"
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
}