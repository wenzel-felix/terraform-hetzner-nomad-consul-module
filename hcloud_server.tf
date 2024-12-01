locals {
  server_configuration = templatefile("${path.module}/scripts/server_setup.sh", {
    enable_nomad_acls = var.enable_nomad_acls
    SERVER_COUNT      = var.nomad_server_count
    IP_RANGE          = var.virtual_network_cidr
    SERVER_IPs        = jsonencode([for server in hcloud_server.server : (server.network[*].ip)[0]])
  })
  client_configuration = templatefile("${path.module}/scripts/client_setup.sh", {
    enable_nomad_acls = var.enable_nomad_acls
    IP_RANGE          = var.virtual_network_cidr
    SERVER_IPs        = jsonencode([for server in hcloud_server.server : (server.network[*].ip)[0]])
  })
}

resource "hcloud_server" "server" {
  depends_on = [
    hcloud_network_subnet.network
  ]
  count       = var.nomad_server_count
  name        = "nomad-server-${count.index}"
  server_type = var.hetzner_server_sku
  image       = "ubuntu-20.04"
  location    = element(var.node_locations, count.index)
  ssh_keys    = [hcloud_ssh_key.default.id]
  labels = {
    "nomad-server" = "any"
  }

  network {
    network_id = hcloud_network.network.id
  }

  public_net {
    ipv6_enabled = false
  }

  user_data = templatefile("${path.module}/scripts/base_configuration.sh", {
    CONSUL_VERSION = var.apt_consul_version
    NOMAD_VERSION  = var.apt_nomad_version
  })

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'"
    ]

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = tls_private_key.machines.private_key_openssh
    }
  }
}

resource "null_resource" "deployment_server" {
  count = var.nomad_server_count
  triggers = {
    "vm" = "${hcloud_server.server[count.index].id}"
    "config" = "${local.server_configuration}"
  }
  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    host        = hcloud_server.server[count.index].ipv4_address
  }

  provisioner "file" {
    content     = local.server_configuration
    destination = "setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup.sh",
      "./setup.sh"
    ]
  }
}

resource "hcloud_server" "client" {
  depends_on = [
    hcloud_network_subnet.network
  ]
  count       = var.nomad_client_count
  name        = "nomad-client-${count.index}"
  server_type = var.hetzner_client_sku
  image       = "ubuntu-20.04"
  location    = element(var.node_locations, count.index)
  ssh_keys    = [hcloud_ssh_key.default.id]
  labels = {
    "nomad-client" = "any"
  }

  network {
    network_id = hcloud_network.network.id
  }

  public_net {
    ipv6_enabled = false
  }

  user_data = templatefile("${path.module}/scripts/base_configuration.sh", {
    CONSUL_VERSION = var.apt_consul_version
    NOMAD_VERSION  = var.apt_nomad_version
  })

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'"
    ]

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = tls_private_key.machines.private_key_openssh
    }
  }
}

resource "null_resource" "deployment_client" {
  count = var.nomad_client_count
  triggers = {
    "vm" = "${hcloud_server.client[count.index].id}"
    "config" = "${local.client_configuration}"
  }
  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    host        = hcloud_server.client[count.index].ipv4_address
  }

  provisioner "file" {
    content     = local.client_configuration
    destination = "setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup.sh",
      "./setup.sh"
    ]
  }
}
