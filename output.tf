output "server_info" {
  value = {
    for server in hcloud_server.main : server.name => {
      "public_ip"   = server.ipv4_address
      "private_ips" = "[${join(", ", server.network != null ? server.network[*].ip : [])}]"
    }
  }
}

data "local_file" "nomad_token" {
  depends_on = [
    null_resource.fetch_nomad_token
  ]
  filename = "tmp/nomad_token"
}

output "nomad_token" {
  value = trimspace(data.local_file.nomad_token.content)
}

output "nomad_address" {
  value = "http://${hcloud_load_balancer.load_balancer.ipv4}:80"
}
