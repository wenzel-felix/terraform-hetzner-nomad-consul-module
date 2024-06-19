terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.47.0"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}

module "hetzner-nomad-consul" {
    source = "../../"
    hetzner_token = var.hetzner_token
    nomad_server_count = 3
    generate_ssh_key_file = true
    enable_nomad_acls = false
}

output "server_info" {
  value = module.hetzner-nomad-consul.server_info
}

output "nomad_address" {
  value = module.hetzner-nomad-consul.nomad_address
}