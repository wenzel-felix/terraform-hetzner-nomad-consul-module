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
  IP_range       = "10.0.0.0/16"
  Server_IPs     = ["10.0.1.2", "10.0.1.3", "10.0.1.4"]
  Client_IPs     = ["10.0.1.5"]
  Aggregator_IPs = merge({ for ip in local.Server_IPs : ip => "server" }, { for ip in local.Client_IPs : ip => "client" })
}

resource "null_resource" "name" {
    triggers = {
      "Configurations" = join(",", [for key, value in local.Aggregator_IPs : "${key}=${value}"])
    }
  provisioner "local-exec" {
    command = <<EOF
        cd tmp
        consul keygen > consul_master.key
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
}

/* 

resource "hcloud_network" "network" {
  name     = "network"
  ip_range = local.IP_range
}

resource "hcloud_server" "server" {
  for_each    = local.Aggregator_IPs
  name        = "server"
  server_type = "cx11"
  image       = "ubuntu-20.04"
  location    = "nbg1"

  network {
    network_id = hcloud_network.network.id
    ip         = each.key
  }
} */