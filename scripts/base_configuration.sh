#!/bin/bash
# Update the server and install needed packages
apt update
apt upgrade
apt install unzip
cd /root/

# To install HashiCorp Consul, we need to download and install the respective binary. First, define the version and host in an environment variable
export CONSUL_VERSION="1.10.1"
export CONSUL_URL="https://releases.hashicorp.com/consul"

# Download the binary, decompress it and install it on your server
curl --silent --remote-name ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
chown root:root consul
mv consul /usr/local/bin/
rm consul_${CONSUL_VERSION}_linux_amd64.zip

# We can now add autocomplete functionality for Consul (optional)
consul -autocomplete-install
complete -C /usr/local/bin/consul consul

# Create a user for Consul
useradd --system --home /etc/consul.d --shell /bin/false consul
mkdir --parents /opt/consul
chown --recursive consul:consul /opt/consul

# Prepare the Consul configuration
mkdir --parents /etc/consul.d
touch /etc/consul.d/consul.hcl
chown --recursive consul:consul /etc/consul.d
chmod 640 /etc/consul.d/consul.hcl

# Prepare the TLS certificates for Consul
consul tls ca create
consul tls cert create -server -dc dc1
consul tls cert create -server -dc dc1
consul tls cert create -server -dc dc1
consul tls cert create -client -dc dc1

# Similar to the Consul binary, we first define the version as a variable
export NOMAD_VERSION="1.1.3"

# Download and install the binary
curl --silent --remote-name https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
unzip nomad_${NOMAD_VERSION}_linux_amd64.zip
chown root:root nomad
mv nomad /usr/local/bin/
rm nomad_${NOMAD_VERSION}_linux_amd64.zip

# Add autocomplete functionality to nomad (optional)
nomad -autocomplete-install
complete -C /usr/local/bin/nomad nomad

# Prepare the data directory
mkdir --parents /opt/nomad

# Create the basic configuration file for nomad
mkdir --parents /etc/nomad.d
chmod 700 /etc/nomad.d
cat <<EOF > /etc/nomad.d/nomad.hcl
datacenter = "dc1"
data_dir = "/opt/nomad"
EOF

# Consul and Nomad should start automatically after boot. To enable this, create a systemd service for both of them.
cat <<EOF > /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=exec
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF