#!/bin/bash

# Similar to the server configuration, we have to copy the certificate to the /etc/consul.d/ folder.
cd /root/
cp consul-agent-ca.pem /etc/consul.d/
cp dc1-client-consul-0* /etc/consul.d/
rm *.pem

# Open the configuration file /etc/consul.d/consul.hcl and add the content
cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "your-symmetric-encryption-key"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/dc1-client-consul-0.pem"
key_file = "/etc/consul.d/dc1-client-consul-0-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
retry_join = ["10.0.0.2"]
bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/8\" | attr \"address\" }}"

check_update_interval = "0s"

acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}

performance {
  raft_multiplier = 1
}
EOF

# Nomad has to be configured as well. For that, add the configuration file /etc/nomad.d/client.hcl with the content
cat <<EOF > /etc/nomad.d/client.hcl
client {
  enabled = true

  network_interface = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/8\" | attr \"name\" }}"
}

acl {
  enabled = true
}
EOF

# To make the snapshot as small as possible, we will only enable the services, but won't start them yet.
systemctl enable consul
systemctl enable nomad

