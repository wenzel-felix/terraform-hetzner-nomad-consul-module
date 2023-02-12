module "hetzner-nomad-consul" {
    source = "../../"
    hetzner_token = var.hetzner_token
    nomad_client_count = 1
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.36.2"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}

data "hcloud_server" "client-0" {
  depends_on = [
    module.hetzner-nomad-consul
  ]
  name = [for key, value in module.hetzner-nomad-consul.server_info: key if length(regexall("client-0.*", key)) > 0][0]
}

resource "hcloud_firewall" "traefik" {
  name = "traefik"

  rule {
    direction = "in"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    port = "8081"
  }
    rule {
    direction = "in"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    port = "80"
  }
}

resource "hcloud_firewall_attachment" "traefik" {
  depends_on = [
    module.hetzner-nomad-consul
  ]
  firewall_id = hcloud_firewall.traefik.id
  server_ids = [
    data.hcloud_server.client-0.id
  ]
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
  name    = "api"
  type    = "A"
  proxied = true
  value   = local.traefik_ip
}
