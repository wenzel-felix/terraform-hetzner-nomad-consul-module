terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.44.1"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}