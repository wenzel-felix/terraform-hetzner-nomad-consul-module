output "server_info" {
  value = {
    for server in hcloud_server.main : server.name => {
      "public_ip"   = server.ipv4_address
      "private_ips" = "[${join(", ", server.network != null ? server.network[*].ip : [])}]"
    }
  }
}

output "nomad_address" {
  value = "http://${hcloud_load_balancer.load_balancer.ipv4}:80"
}

output "network_id" {
  value = hcloud_network.network.id
}

output "tls_private_key" {
  value = tls_private_key.machines.private_key_pem
}