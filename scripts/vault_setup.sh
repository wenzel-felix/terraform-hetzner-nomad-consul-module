#!/bin/bash

wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install jq vault -y

#openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -x509 -days 3650 -out tls.crt -subj "/O=HashiCorp/CN=Vault" -addext 'subjectAltName = IP:127.0.0.1'
#chown vault: /opt/vault/tls/*
cat <<EOF >/etc/vault.d/vault.hcl
storage "file" {
  path = "/mnt/vault/data"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = "true"
}

api_addr = "http://127.0.0.1:8200"
ui = true
EOF


vault server -config=/etc/vault.d/vault.hcl &
sleep 10
export VAULT_ADDR=http://127.0.0.1:8200
vault operator init -format=json | jq '.root_token, .unseal_keys_b64[]'
