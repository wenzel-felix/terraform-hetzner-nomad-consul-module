resource "hcloud_server" "main" {
  depends_on = [
    hcloud_network_subnet.network
  ]
  for_each    = local.Aggregator_Data
  name        = each.key
  server_type = "cpx11"
  image       = "ubuntu-20.04"
  location    = var.hetzner_datacenter
  ssh_keys    = [hcloud_ssh_key.default.id]
  labels = {
    "nomad-${each.value.type}" = "any"
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

resource "null_resource" "deployment" {
  for_each = local.Extended_Aggregator_IPs
  triggers = {
    "vm" = "${hcloud_server.main[each.key].id}"
  }
  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    host        = each.value.public_ipv4
  }

  provisioner "file" {
    content = each.value.type == "server" ? templatefile("${path.module}/scripts/server_setup.sh",
        {
          enable_nomad_acls = var.enable_nomad_acls
          SERVER_COUNT = length(local.Server_Count)
          IP_RANGE     = local.IP_range
          SERVER_IPs   = jsonencode([for key, value in local.Extended_Aggregator_IPs : value.private_ipv4[0] if value.type == "server"])
        }) : templatefile("${path.module}/scripts/client_setup.sh",
        {
          enable_nomad_acls = var.enable_nomad_acls
          SERVER_COUNT = length(local.Server_Count)
          IP_RANGE     = local.IP_range
          SERVER_IPs   = jsonencode([for key, value in local.Extended_Aggregator_IPs : value.private_ipv4[0] if value.type == "server"])
      })
    destination = "setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup.sh",
      "./setup.sh"
    ]
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.machines.private_key_openssh
  filename        = "${path.root}/certs/machines.pem"
  file_permission = "0600"
}

resource "tls_private_key" "machines" {
  algorithm = "RSA"
}

resource "hcloud_ssh_key" "default" {
  name       = "default"
  public_key = tls_private_key.machines.public_key_openssh
}

resource "null_resource" "clean_up" {
  provisioner "local-exec" {
    command = <<EOF
      rm -f ${path.root}/certs/machines.pem
    EOF
    when    = destroy
  }
}
