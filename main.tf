terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.38.2"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}

locals {
  IP_range     = var.virtual_network_cidr
  Server_Count = range(var.nomad_server_count)
  Client_Count = range(var.nomad_client_count)
  Aggregator_Data = merge({ for id in local.Server_Count : "server-${id}" => {
    "type" = "server"
    "id"   = id
    } }, { for id in local.Client_Count : "client-${id}" => {
    "type" = "client"
    "id"   = id
  } })
  Extended_Aggregator_IPs = {
    for key, value in local.Aggregator_Data : key => {
      "private_ipv4" = hcloud_server.main[key].network[*].ip
      "public_ipv4"  = hcloud_server.main[key].ipv4_address
      "type"         = value.type
      "id"           = value.id
    }
  }
}