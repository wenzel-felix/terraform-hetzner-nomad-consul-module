#!/bin/bash

ssh -i tmp/machines.pem -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$1 curl --request POST http://localhost:4646/v1/acl/bootstrap | jq -r '.SecretID' > tmp/nomad_token
cat tmp/nomad_token