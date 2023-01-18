resource "hcloud_server" "main" {
  depends_on = [
    hcloud_network_subnet.network,
    hcloud_server.vault
  ]
  for_each    = local.Aggregator_Data
  name        = "${each.key}"
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
    content     = tls_private_key.machines.private_key_openssh
    destination = "machines.pem"
  }

  provisioner "file" {
    content     = join("\n", [file("${path.module}/scripts/base_configuration.sh"), data.template_file.base_configuration[each.key].rendered])
    destination = "setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup.sh",
      "./setup.sh"
    ]
  }
}

resource "time_sleep" "wait_60_seconds" {
  depends_on      = [null_resource.deployment]
  create_duration = "60s"
}

resource "null_resource" "fetch_nomad_token" {
  depends_on = [time_sleep.wait_60_seconds]

  provisioner "local-exec" {
    command = <<EOF
      for i in ${join(" ", [for server in hcloud_server.main : server.ipv4_address if length(regexall("server.*", server.name)) > 0])}
      do
        ssh -i ${path.root}/certs/machines.pem -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$i curl --request POST http://localhost:4646/v1/acl/bootstrap | jq -r -R 'fromjson? | .SecretID?' >> ${path.root}/certs/nomad_token
      done
    EOF
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
  name       = "Terraform Example"
  public_key = tls_private_key.machines.public_key_openssh
}

resource "null_resource" "clean_up" {
  provisioner "local-exec" {
    command = <<EOF
      rm -f ${path.root}/certs/nomad_token
      rm -f ${path.root}/certs/machines.pem
    EOF
    when = destroy
  }
}