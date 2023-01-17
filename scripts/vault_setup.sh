#!/bin/bash

wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install jq vault -y

#openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -x509 -days 3650 -out tls.crt -subj "/O=HashiCorp/CN=Vault" -addext 'subjectAltName = IP:127.0.0.1'
#chown vault: /opt/vault/tls/*
mkdir -p /mnt/vault
chown vault: /mnt/vault
cat <<EOF >/etc/vault.d/vault.hcl
storage "file" {
  path = "/mnt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

api_addr = "http://127.0.0.1:8200"
ui = true
EOF

cat <<EOF > /etc/systemd/system/consul.service
### BEGIN INIT INFO
# Provides:          vault
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Vault server
# Description:       Vault secret management tool
### END INIT INFO

[Unit]
Description=Vault secret management tool
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl -log-level=debug
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl enable vault
systemctl start vault

sleep 10
export VAULT_ADDR=http://127.0.0.1:8200
vault operator init -format=json | jq -r '.root_token, .unseal_keys_b64[]' > vault_keys
vault operator unseal $(cat vault_keys | head -n2 | tail -n1)
vault operator unseal $(cat vault_keys | head -n3 | tail -n1)
vault operator unseal $(cat vault_keys | head -n4 | tail -n1)
sleep 5
vault login $(cat vault_keys | head -n1 | tail -n1)
vault login -token-only $(cat vault_keys | head -n1 | tail -n1) > vault_token
vault secrets enable -path=connect_root pki
vault secrets enable -path=connect_dc1_inter pki

cat <<EOF > vault-policy-connect-ca.hcl
path "/sys/mounts/connect_root" {
  capabilities = [ "read" ]
}

path "/sys/mounts/connect_dc1_inter" {
  capabilities = [ "read" ]
}

path "/sys/mounts/connect_dc1_inter/tune" {
  capabilities = [ "update" ]
}

path "/connect_root/" {
  capabilities = [ "read" ]
}

path "/connect_root/root/sign-intermediate" {
  capabilities = [ "update" ]
}

path "/connect_dc1_inter/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "auth/token/renew-self" {
  capabilities = [ "update" ]
}

path "auth/token/lookup-self" {
  capabilities = [ "read" ]
}
EOF
vault policy write connect-ca vault-policy-connect-ca.hcl
vault token create -policy=connect-ca -format=json | jq -r '.auth.client_token' > connect_ca_token
