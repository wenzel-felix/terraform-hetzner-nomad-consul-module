resource "random_string" "vault" {
  length   = 16
  special  = false
}

resource "hcloud_server" "vault" {
  depends_on = [
    hcloud_network_subnet.network
  ]
  name        = "vault-0-${random_string.vault.result}"
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

output "name" {
  value = hcloud_server.vault.ipv4_address
}

locals {
  Consul_IPs = ["10.0.0.10", "10.0.0.11"]
}

resource "null_resource" "vault_deployment" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    host        = hcloud_server.vault.ipv4_address
  }

  provisioner "file" {
    content     = tls_private_key.machines.private_key_openssh
    destination = "machines.pem"
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