output "server_info" {
  value = {
    for server in hcloud_server.main : server.name => {
      "public_ip" = server.ipv4_address
      "private_ips" = "[${join(", ", server.network != null ? server.network[*].ip : [])}]"
    }
  }
}
