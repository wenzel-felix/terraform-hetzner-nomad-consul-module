module "hetzner-nomad-consul" {
    source = "../../"
    hetzner_token = var.hetzner_token
}

output "server_info" {
  value = module.hetzner-nomad-consul.server_info
}

output "nomad_token" {
  value = module.hetzner-nomad-consul.nomad_token
}

output "nomad_address" {
  value = module.hetzner-nomad-consul.nomad_address
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

resource "cloudflare_record" "nomad" {
  zone_id = var.cloudflare_zone_id
  name    = "nomad"
  type    = "A"
  proxied = true
  value   = split(":", split("//", module.hetzner-nomad-consul.nomad_address)[1])[0]
}

locals {
  traefik_ip = [for key, value in module.hetzner-nomad-consul.server_info: value.public_ip if length(regexall("client-0.*", key)) > 0][0]
}

resource "cloudflare_record" "traefik" {
  zone_id = var.cloudflare_zone_id
  name    = "traefik"
  type    = "A"
  proxied = true
  value   = local.traefik_ip
}
