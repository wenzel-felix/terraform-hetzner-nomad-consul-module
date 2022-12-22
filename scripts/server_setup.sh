#!/bin/bash

# First, create a symmetric encryption key, which will be shared between all servers. Save this key in a secure location, we will need it in the next steps.
consul keygen

# Now we can copy the right certificates from step 1 to the Consul configuration directory. Run the following command on all servers
cp consul-agent-ca.pem /etc/consul.d/

# To check if you have all the files you need, you should get a similar output for your servers (X being the respective certificate number)To check if you have all the files you need, you should get a similar output for your servers (X being the respective certificate number)
ls /etc/consul.d/

# Finally, delete all cert files and keys in your root directory on every server
cd /root/
rm *.pem

# On all servers, edit the configuration file /etc/consul.d/consul.hcl and add the content
cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "your-symmetric-encryption-key"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/dc1-server-consul-0.pem"
key_file = "/etc/consul.d/dc1-server-consul-0-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
retry_join = ["10.0.0.2"]
bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/8\" | attr \"address\" }}"

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
bootstrap_expect = 3
EOF

# Create the configuration file /etc/nomad.d/server.hcl with the content
cat <<EOF > /etc/nomad.d/server.hcl
server {
  enabled = true
  bootstrap_expect = 3
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
consul members

# Since we use ACLs (Access Control Lists) on Nomad, we have to get the bootstrap token first, before checking the status here as well.
export NOMAD_TOKEN=$(nomad acl bootstrap)
echo "$NOMAD_TOKEN" > /nomad_token
nomad server members




