resource "hcloud_network" "network" {
  name     = "network"
  ip_range = var.virtual_network_cidr
}

resource "hcloud_network_subnet" "network" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = var.hetzner_network_zone
  ip_range     = var.virtual_network_cidr
}