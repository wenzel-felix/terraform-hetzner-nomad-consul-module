module "hetzner-nomad-consul" {
    source = "../../"
    hetzner_token = var.hetzner_token
    enable_nomad_acls = false
    nomad_server_count = 1
}

output "server_info" {
  value = module.hetzner-nomad-consul.server_info
}

output "nomad_address" {
  value = module.hetzner-nomad-consul.nomad_address
}