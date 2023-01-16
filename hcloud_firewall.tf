/* resource "hcloud_firewall" "default" {
  name = "default-firewall"
  rule {
    direction = "in"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    port = "22"
  }
}

resource "hcloud_firewall_attachment" "default" {
  depends_on = [
    hcloud_server.main,
    hcloud_server.vault
  ]
  firewall_id = hcloud_firewall.default.id
  label_selectors = [ "nomad-server", "nomad-client", "vault-server" ]
} */