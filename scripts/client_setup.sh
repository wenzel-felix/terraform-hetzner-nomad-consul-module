# Open the configuration file /etc/consul.d/consul.hcl and add the content
cat <<EOF >/etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"

connect {
  enabled = true
}

retry_join = ${SERVER_IPs}
bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"${IP_RANGE}\" | attr \"address\" }}"

check_update_interval = "0s"

acl = {
  enabled = true
  default_policy = "allow"
  down_policy    = "extend-cache"
}

performance {
  raft_multiplier = 1
}
EOF

# Nomad has to be configured as well. For that, add the configuration file /etc/nomad.d/client.hcl with the content
cat <<EOF >/etc/nomad.d/client.hcl
client {
  enabled = true

  network_interface = "{{ GetPrivateInterfaces | include \"network\" \"${IP_RANGE}\" | attr \"name\" }}"
}

acl {
  %{ if bootstrap }enabled        = false%{ else }enabled        = true%{ endif }
}
EOF

# Install Docker Engine
apt remove docker docker-engine docker.io containerd runc -y
apt install ca-certificates curl gnupg lsb-release -y
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

# Install CNI plugins https://developer.hashicorp.com/nomad/docs/integrations/consul-connect?ref=karan-sharma#cni-plugins
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.0/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

# To make the snapshot as small as possible, we will only enable the services, but won't start them yet.
systemctl enable consul
systemctl enable nomad

systemctl start consul
systemctl start nomad
