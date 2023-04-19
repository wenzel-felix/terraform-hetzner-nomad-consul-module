# hetzner-nomad-consul

This module allows you to create a manually-scalable high-availability nomad cluster on Hetzner Cloud.
You only need to provide a API token as variable and a default cluster with 3 servers and 1 client will be created.

## Advanced Usage

The module is mainly addressed to people who want to test the technology running terraform on their local PC, but it can be used in professional workflows as well.

## Get ACL if enabled
```
curl --request POST http://<loadbalancerIP>/v1/acl/bootstrap | jq -r -R 'fromjson? | .SecretID?'
```
