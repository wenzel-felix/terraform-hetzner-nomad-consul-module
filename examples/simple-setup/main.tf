module "hetzner-nomad-consul" {
    source = "../../"
    hetzner_token = var.hetzner_token
}

/* output "server_info" {
  value = module.hetzner-nomad-consul.server_info
}

output "nomad_token" {
  value = module.hetzner-nomad-consul.nomad_token
}

output "nomad_address" {
  value = module.hetzner-nomad-consul.nomad_address
} */