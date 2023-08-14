terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.42.1"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}