# On all servers, edit the configuration file /etc/consul.d/consul.hcl and add the content
cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"

connect {
  enabled = true
}
client_addr = "0.0.0.0"
ui_config {
  enabled = true
}
retry_join = ${SERVER_IPs}
bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"${IP_RANGE}\" | attr \"address\" }}"

acl = {
  enabled = true
  default_policy = "allow"
  down_policy    = "extend-cache"
}

performance {
  raft_multiplier = 1
}
EOF

sed -i -r "s/Your_Vault_Token/$(cat /etc/consul.d/connect_ca_token)/" /etc/consul.d/consul.hcl

# Check the configuration with the command
consul validate /etc/consul.d/consul.hcl

# On all servers, create the configuration file /etc/consul.d/server.hcl with the following content
cat <<EOF > /etc/consul.d/server.hcl
server = true
bootstrap_expect = ${SERVER_COUNT}
EOF

# Create the configuration file /etc/nomad.d/server.hcl with the content
cat <<EOF > /etc/nomad.d/server.hcl
server {
  enabled = true
  bootstrap_expect = ${SERVER_COUNT}
}

acl {
  %{ if bootstrap }enabled        = true%{ else }enabled        = false%{ endif }
}
EOF

# Enable both services on all servers
systemctl enable consul
systemctl enable nomad

# and start the services
systemctl start consul
systemctl start nomad

#reboot