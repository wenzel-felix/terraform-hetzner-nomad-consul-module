# Now we can copy the right certificates from step 1 to the Consul configuration directory. Run the following command on all servers
cat <<EOF > /etc/consul.d/consul-agent-ca.pem
${CONSUL_AGENT_CA_PEM}
EOF

cat <<EOF > /etc/consul.d/dc1-server-consul.pem
${DC1_CONSUL_PEM}
EOF

cat <<EOF > /etc/consul.d/dc1-server-consul-key.pem
${DC1_CONSUL_KEY_PEM}
EOF

# Finally, delete all cert files and keys in your root directory on every server
cd /root/

# On all servers, edit the configuration file /etc/consul.d/consul.hcl and add the content
cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "${MASTER_KEY}"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/dc1-server-consul.pem"
key_file = "/etc/consul.d/dc1-server-consul-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
retry_join = ${SERVER_IPs}
bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"${IP_RANGE}\" | attr \"address\" }}"

acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}

performance {
  raft_multiplier = 1
}
EOF

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
  enabled = true
}
EOF

# Enable both services on all servers
systemctl enable consul
systemctl enable nomad

# and start the services
systemctl start consul
systemctl start nomad

# To check the cluster, run the following command on one of your servers
#consul members


# Since we use ACLs (Access Control Lists) on Nomad, we have to get the bootstrap token first, before checking the status here as well.
#nomad server members

reboot
