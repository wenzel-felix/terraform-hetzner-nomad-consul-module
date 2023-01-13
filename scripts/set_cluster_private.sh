#!/bin/bash

# Fetch all servers and their PIPs
SERVER_IDs=$(curl -H "Authorization: Bearer $1" 'https://api.hetzner.cloud/v1/servers' | jq -r '.servers | .[].id')

for id in $SERVER_IDs
do
  # Power off all servers
  curl -X POST -H "Authorization: Bearer $1" "https://api.hetzner.cloud/v1/servers/$id/actions/poweroff"
  sleep 15
  # Get server details
  IP_ID=$(curl -H "Authorization: Bearer $1" "https://api.hetzner.cloud/v1/servers/$id" | jq -r '.server.public_net.ipv4.id // empty')
  # Remove PIPs from the server
  if [ ! -z "$IP_ID" ]
  then
    curl -X DELETE -H "Authorization: Bearer $1" "https://api.hetzner.cloud/v1/primary_ips/$IP_ID"
  fi
  sleep 5
  # Power on all servers
  curl -X POST -H "Authorization: Bearer $1" "https://api.hetzner.cloud/v1/servers/$id/actions/poweron"
done
