terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.36.1"
    }
  }
}

provider "hcloud" {
  token = local.hcloud_token
}

locals {
  IP_range   = "10.0.0.0/16"
  Server_IPs = ["10.0.0.2", "10.0.0.3", "10.0.0.4"]
  Client_IPs = ["10.0.0.5"]
  Aggregator_IPs = merge({ for ip in local.Server_IPs : ip => {
    "type" = "server"
    "id"   = index(local.Server_IPs, ip)
    } }, { for ip in local.Client_IPs : ip => {
    "type" = "client"
    "id"   = index(local.Client_IPs, ip)
  } })
}

resource "null_resource" "name" {
  triggers = {
    "Configurations" = join(",", [for key, value in local.Aggregator_IPs : "${key}=${value.type}"])
  }

  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
        cd tmp
        consul keygen | tr -d '\n' > consul_master.key
        consul tls ca create
        for i in {1..${length(local.Server_IPs)}}
        do
          consul tls cert create -server -dc dc1
        done
        for i in {1..${length(local.Client_IPs)}}
        do
          consul tls cert create -client -dc dc1
        done
    EOF
  }

  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
        rm tmp/[a-zA-Z0-9]*
    EOF
    when    = destroy
  }
}

data "template_file" "base_configuration" {
  for_each = local.Aggregator_IPs
  template = each.value.type == "server" ? file("scripts/server_setup.sh") : file("scripts/client_setup.sh")
  vars = {
    CONSUL_AGENT_CA_PEM = data.local_file.consul_agent_ca_pem.content
    DC1_CONSUL_PEM      = data.local_file.dc1_consul_pem[each.key].content
    DC1_CONSUL_KEY_PEM  = data.local_file.dc1_consul_key_pem[each.key].content
    MASTER_KEY          = data.local_file.consul_master_key.content
    SERVER_COUNT        = length(local.Server_IPs)
    IP_RANGE            = local.IP_range
    SERVER_IPs          = jsonencode(local.Server_IPs)
  }
}

data "local_file" "consul_agent_ca_pem" {
  depends_on = [
    null_resource.name
  ]
  filename = "tmp/consul-agent-ca.pem"
}

data "local_file" "consul_master_key" {
  depends_on = [
    null_resource.name
  ]
  filename = "tmp/consul_master.key"
}

data "local_file" "dc1_consul_pem" {
  depends_on = [
    null_resource.name
  ]
  for_each = local.Aggregator_IPs
  filename = "tmp/dc1-${each.value.type}-consul-${each.value.id}.pem"
}

data "local_file" "dc1_consul_key_pem" {
  depends_on = [
    null_resource.name
  ]
  for_each = local.Aggregator_IPs
  filename = "tmp/dc1-${each.value.type}-consul-${each.value.id}-key.pem"
}

resource "random_string" "random" {
  for_each = local.Aggregator_IPs
  length   = 16
  special  = false
}

resource "hcloud_network" "network" {
  name     = "network"
  ip_range = local.IP_range
}

resource "hcloud_network_subnet" "network" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = local.IP_range
}

resource "hcloud_server" "main" {
  depends_on = [
    hcloud_network_subnet.network
  ]
  for_each    = local.Aggregator_IPs
  name        = "${each.value.type}-${random_string.random[each.key].result}"
  server_type = "cx11"
  image       = "ubuntu-20.04"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.default.id]
  labels = {
    "nomad-${each.value.type}" = "any"
  }

  network {
    network_id = hcloud_network.network.id
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    host        = self.ipv4_address
  }

  provisioner "file" {
    content     = join("\n", [file("scripts/base_configuration.sh"), data.template_file.base_configuration[each.key].rendered])
    destination = "setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup.sh",
      "./setup.sh"
    ]
  }
}

resource "hcloud_load_balancer" "load_balancer" {
  name               = "my-load-balancer"
  load_balancer_type = "lb11"
  location           = "nbg1"
}

resource "hcloud_load_balancer_network" "srvnetwork" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id       = hcloud_network.network.id
}

resource "hcloud_load_balancer_service" "load_balancer_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 4646
  http {
    sticky_sessions = true
  }
  health_check {
    protocol = "http"
    port     = 4646
    interval = 10
    timeout  = 5
    retries  = 3
    http {
      path = "/v1/status/leader"
    }
  }
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  label_selector   = "nomad-server"
  use_private_ip   = true
}

resource "tls_private_key" "machines" {
  algorithm = "RSA"
}

resource "hcloud_ssh_key" "default" {
  name       = "Terraform Example"
  public_key = tls_private_key.machines.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.machines.private_key_openssh
  filename        = "tmp/machines.pem"
  file_permission = "0600"
}

resource "local_file" "load_balancer_ip" {
  content         = hcloud_load_balancer.load_balancer.ipv4
  filename        = "tmp/nomad_address"
}

resource "time_sleep" "wait_15_seconds" {
  depends_on      = [hcloud_server.main]
  create_duration = "15s"
}

resource "null_resource" "fetch_nomad_token" {
  depends_on = [time_sleep.wait_15_seconds]

  provisioner "local-exec" {
    command = <<EOF
      for i in ${join(" ", [for server in hcloud_server.main : server.ipv4_address if length(regexall("server.*", server.name)) > 0])}
      do
        ssh -i tmp/machines.pem -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$i curl --request POST http://localhost:4646/v1/acl/bootstrap | jq -r -R 'fromjson? | .SecretID?' >> tmp/nomad_token
      done
    EOF
  }
}