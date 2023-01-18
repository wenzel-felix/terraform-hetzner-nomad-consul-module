resource "hcloud_server" "vault" {
  depends_on = [
    hcloud_network_subnet.network
  ]
  name        = "vault-0"
  server_type = "cpx11"
  image       = "ubuntu-20.04"
  location    = var.hetzner_datacenter
  ssh_keys    = [hcloud_ssh_key.default.id]
  labels = {
    "vault-server" = "any"
  }

  network {
    network_id = hcloud_network.network.id
  }

  public_net {
    ipv6_enabled = false
  }
}

output "vault_ip" {
  value = hcloud_server.vault.ipv4_address
}

resource "null_resource" "vault_deployment" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    host        = hcloud_server.vault.ipv4_address
  }

  provisioner "file" {
    content     = file("${path.module}/scripts/vault_setup.sh")
    destination = "setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup.sh",
      "./setup.sh"
    ]
  }
}