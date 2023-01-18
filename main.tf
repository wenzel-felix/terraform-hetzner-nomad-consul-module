terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.36.2"
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

data "template_file" "base_configuration" {
  for_each = local.Aggregator_Data
  template = each.value.type == "server" ? file("${path.module}/scripts/server_setup.sh") : file("${path.module}/scripts/client_setup.sh")
  vars = {
    VAULT_IP = hcloud_server.vault.ipv4_address
    SERVER_COUNT        = length(local.Server_Count)
    IP_RANGE            = local.IP_range
    SERVER_IPs          = jsonencode([for key, value in local.Extended_Aggregator_IPs : value.private_ipv4[0] if value.type == "server"])
  }
}