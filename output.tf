output "server_info" {
  value = {
    for server in hcloud_server.main : server.name => {
      "public_ip"   = server.ipv4_address
      "private_ips" = "[${join(", ", server.network != null ? server.network[*].ip : [])}]"
    }
  }
}

output "nomad_token" {
  value = fileexists("certs/nomad_token") ? trimspace(file("certs/nomad_token")) : "Could not find nomad token file from initial bootstrap. If this is your initial apply, please create a GitHub issue."
}

output "nomad_address" {
  value = "http://${hcloud_load_balancer.load_balancer.ipv4}:80"
}

output "network_id" {
  value = hcloud_network.network.id
}
