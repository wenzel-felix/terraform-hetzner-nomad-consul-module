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
    when = destroy
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
  for_each    = local.Aggregator_IPs
  length           = 16
  special          = false
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

resource "hcloud_server" "server" {
  depends_on = [
    hcloud_network_subnet.network
  ]
  for_each    = local.Aggregator_IPs
  name        = "server-${random_string.random[each.key].result}"
  server_type = "cx11"
  image       = "ubuntu-20.04"
  location    = "nbg1"

  network {
    network_id = hcloud_network.network.id
    ip         = each.key
  }

  user_data = join("\n", [file("scripts/base_configuration.sh"), data.template_file.base_configuration[each.key].rendered])
}