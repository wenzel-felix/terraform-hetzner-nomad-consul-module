module "hetzner-nomad-consul" {
    source = "../../"
    hetzner_token = var.hetzner_token
    nomad_server_count = 3
    generate_ssh_key_file = true
    enable_nomad_acls = true
}

output "server_info" {
  value = module.hetzner-nomad-consul.server_info
}

output "nomad_address" {
  value = module.hetzner-nomad-consul.nomad_address
}