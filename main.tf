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
/*   Extended_Aggregator_IPs = {
    for key, value in local.Aggregator_Data : key => {
      "private_ipv4" = hcloud_server.main[key].network[*].ip
      "public_ipv4"  = hcloud_server.main[key].ipv4_address
      "type"         = value.type
      "id"           = value.id
    }
  } */
}

/* resource "null_resource" "create_root_certs" {
  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
        mkdir -p ${path.root}/certs
        mkdir -p ${path.root}/tmp
        cd ${path.root}/certs
        if [[ ! -f "consul-agent-ca-key.pem" ]] || [[ ! -f "consul-agent-ca.pem" ]]
        then
          echo "Creating new CA"
          rm ./consul-agent-ca-key.pem
          rm ./consul-agent-ca.pem
          consul tls ca create
        fi
        if [[ ! -f "consul_master.key" ]]
        then
          echo "Creating new Consul agent encryption key"
          consul keygen | tr -d '\n' > consul_master.key
        fi
    EOF
  }
  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
        rm -rf ${path.root}/certs/
        rm -rf ${path.root}/tmp/
    EOF
    when    = destroy
  }
}

resource "null_resource" "create_client_certs" {
  depends_on = [
    null_resource.create_root_certs
  ]
  for_each = { for key, value in local.Aggregator_Data : key => value if value.type == "client" }

  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
    mkdir -p ${path.root}/tmp/${each.key}
    cd ${path.root}/tmp/${each.key}
    consul tls cert create -client -dc dc1 -ca ../../certs/consul-agent-ca.pem -key ../../certs/consul-agent-ca-key.pem
    cd ../..
    echo ${path.root}
    mv ${path.root}/tmp/${each.key}/dc1-client-consul-0-key.pem ${path.root}/certs/dc1-client-consul-${each.value.id}-key.pem
    mv ${path.root}/tmp/${each.key}/dc1-client-consul-0.pem ${path.root}/certs/dc1-client-consul-${each.value.id}.pem
    rm -rf ${path.root}/tmp/${each.key}
    EOF
  }
}

resource "null_resource" "create_server_certs" {
  depends_on = [
    null_resource.create_root_certs
  ]
  for_each = { for key, value in local.Aggregator_Data : key => value if value.type == "server" }

  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
    mkdir -p ${path.root}/tmp/${each.key}
    cd ${path.root}/tmp/${each.key}
    consul tls cert create -server -dc dc1 -ca ../../certs/consul-agent-ca.pem -key ../../certs/consul-agent-ca-key.pem
    cd ../..
    echo ${path.root}
    mv ${path.root}/tmp/${each.key}/dc1-server-consul-0-key.pem ${path.root}/certs/dc1-server-consul-${each.value.id}-key.pem
    mv ${path.root}/tmp/${each.key}/dc1-server-consul-0.pem ${path.root}/certs/dc1-server-consul-${each.value.id}.pem
    rm -rf ${path.root}/tmp/${each.key}
    EOF
  }
}

data "template_file" "base_configuration" {
  for_each = local.Aggregator_Data
  template = each.value.type == "server" ? file("${path.module}/scripts/server_setup.sh") : file("${path.module}/scripts/client_setup.sh")
  vars = {
    CONSUL_AGENT_CA_PEM = data.local_file.consul_agent_ca_pem.content
    DC1_CONSUL_PEM      = data.local_file.dc1_consul_pem[each.key].content
    DC1_CONSUL_KEY_PEM  = data.local_file.dc1_consul_key_pem[each.key].content
    MASTER_KEY          = data.local_file.consul_master_key.content
    SERVER_COUNT        = length(local.Server_Count)
    IP_RANGE            = local.IP_range
    SERVER_IPs          = jsonencode([for key, value in local.Extended_Aggregator_IPs : value.private_ipv4[0] if value.type == "server"])
  }
}

data "local_file" "consul_agent_ca_pem" {
  depends_on = [
    null_resource.create_root_certs
  ]
  filename = "${path.root}/certs/consul-agent-ca.pem"
}

data "local_file" "consul_master_key" {
  depends_on = [
    null_resource.create_root_certs
  ]
  filename = "${path.root}/certs/consul_master.key"
}

data "local_file" "dc1_consul_pem" {
  depends_on = [
    null_resource.create_server_certs,
    null_resource.create_client_certs
  ]
  for_each = local.Aggregator_Data
  filename = "${path.root}/certs/dc1-${each.value.type}-consul-${each.value.id}.pem"
}

data "local_file" "dc1_consul_key_pem" {
  depends_on = [
    null_resource.create_server_certs,
    null_resource.create_client_certs
  ]
  for_each = local.Aggregator_Data
  filename = "${path.root}/certs/dc1-${each.value.type}-consul-${each.value.id}-key.pem"
} */