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
  IP_range     = "10.0.0.0/16"
  Server_Count = range(3)
  Client_Count = range(1)
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

resource "null_resource" "create_root_certs" {
  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
        cd certs
        consul keygen | tr -d '\n' > consul_master.key
        consul tls ca create
    EOF
  }

  provisioner "local-exec" {
    interpreter = [
      "/bin/bash", "-c"
    ]
    command = <<EOF
        rm certs/[a-zA-Z0-9]*
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
    cd tmp
    mkdir ${each.key}
    cd ${each.key}
    consul tls cert create -client -dc dc1 -ca ../../certs/consul-agent-ca.pem -key ../../certs/consul-agent-ca-key.pem
    mv dc1-client-consul-0-key.pem ../../certs/dc1-client-consul-${each.value.id}-key.pem
    mv dc1-client-consul-0.pem ../../certs/dc1-client-consul-${each.value.id}.pem
    cd .. 
    rm -rf ${each.key}
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
    cd tmp
    mkdir ${each.key}
    cd ${each.key}
    consul tls cert create -server -dc dc1 -ca ../../certs/consul-agent-ca.pem -key ../../certs/consul-agent-ca-key.pem
    mv dc1-server-consul-0-key.pem ../../certs/dc1-server-consul-${each.value.id}-key.pem
    mv dc1-server-consul-0.pem ../../certs/dc1-server-consul-${each.value.id}.pem
    cd .. 
    rm -rf ${each.key}
    EOF
  }
}

data "template_file" "base_configuration" {
  for_each = local.Aggregator_Data
  template = each.value.type == "server" ? file("scripts/server_setup.sh") : file("scripts/client_setup.sh")
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
  filename = "certs/consul-agent-ca.pem"
}

data "local_file" "consul_master_key" {
  depends_on = [
    null_resource.create_root_certs
  ]
  filename = "certs/consul_master.key"
}

data "local_file" "dc1_consul_pem" {
  depends_on = [
    null_resource.create_server_certs,
    null_resource.create_client_certs
  ]
  for_each = local.Aggregator_Data
  filename = "certs/dc1-${each.value.type}-consul-${each.value.id}.pem"
}

data "local_file" "dc1_consul_key_pem" {
  depends_on = [
    null_resource.create_server_certs,
    null_resource.create_client_certs
  ]
  for_each = local.Aggregator_Data
  filename = "certs/dc1-${each.value.type}-consul-${each.value.id}-key.pem"
}

resource "random_string" "random" {
  for_each = local.Aggregator_Data
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
  for_each    = local.Aggregator_Data
  name        = "${each.key}-${random_string.random[each.key].result}"
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
      status_codes = [
        "2??",
        "3??",
      ]
    }
  }
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  depends_on = [
    hcloud_load_balancer_network.srvnetwork
  ]
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
  filename        = "certs/machines.pem"
  file_permission = "0600"
}

resource "local_file" "load_balancer_ip" {
  content  = hcloud_load_balancer.load_balancer.ipv4
  filename = "certs/nomad_address"
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
        ssh -i certs/machines.pem -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$i curl --request POST http://localhost:4646/v1/acl/bootstrap | jq -r -R 'fromjson? | .SecretID?' >> certs/nomad_token
      done
    EOF
  }
}

resource "hcloud_firewall" "default" {
  name = "default-firewall"
  rule {
    direction = "in"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    port = "22"
  }
}

resource "hcloud_firewall_attachment" "fw_ref" {
  firewall_id = hcloud_firewall.default.id
  server_ids  = [for server in hcloud_server.main : server.id]
}

resource "hcloud_load_balancer" "app_load_balancer" {
  name               = "my-app-load-balancer"
  load_balancer_type = "lb11"
  location           = "nbg1"
}

resource "hcloud_load_balancer_network" "app_load_balancer" {
  load_balancer_id = hcloud_load_balancer.app_load_balancer.id
  network_id       = hcloud_network.network.id
}

resource "hcloud_load_balancer_service" "app_load_balancer_service_traefik_dashboard" {
  load_balancer_id = hcloud_load_balancer.app_load_balancer.id
  protocol         = "http"
  listen_port      = 8081
  destination_port = 8081
  http {
    sticky_sessions = true
  }
  health_check {
    protocol = "http"
    port     = 8081
    interval = 10
    timeout  = 5
    retries  = 3
    http {
      path = "/"
      status_codes = [
        "2??",
        "3??",
      ]
    }
  }
}

resource "hcloud_load_balancer_service" "app_load_balancer_service_traefik_proxy" {
  load_balancer_id = hcloud_load_balancer.app_load_balancer.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 8080
  http {
    sticky_sessions = true
  }
  health_check {
    protocol = "http"
    port     = 8081
    interval = 10
    timeout  = 5
    retries  = 3
    http {
      path = "/"
      status_codes = [
        "2??",
        "3??",
      ]
    }
  }
}

resource "hcloud_load_balancer_target" "app_load_balancer_target" {
  depends_on = [
    hcloud_load_balancer_network.app_load_balancer
  ]
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.app_load_balancer.id
  label_selector   = "nomad-client"
  use_private_ip   = true
}