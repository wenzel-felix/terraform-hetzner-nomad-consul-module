terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.40.0"
    }
  }
}

provider "hcloud" {
  token = var.hetzner_token
}