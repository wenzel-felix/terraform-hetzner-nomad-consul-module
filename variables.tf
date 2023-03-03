variable "hetzner_token" {
    type        = string
    description = "Hetzner Cloud API Token"
}

variable "virtual_network_cidr" {
    type        = string
    description = "CIDR of the virtual network"
    default = "10.0.0.0/16"
}

variable "nomad_server_count" {
    type        = number
    description = "Number of servers to create"
    default = 3
}

variable "nomad_client_count" {
    type        = number
    description = "Number of clients to create"
    default = 1
}

variable "hetzner_datacenter" {
    type        = string
    description = "Hetzner Cloud Datacenter"
    default = "hel1"
}

variable "bootstrap" {
    type        = bool
    description = "Bootstrap Nomad without ACLs"
    default = true
}

variable "hetzner_network_zone" {
    type        = string
    description = "Hetzner Cloud Network Zone"
    default = "eu-central"
}

variable "apt_consul_version" {
  type = string
    description = "Consul version to install"
    default = "1.15.0-1"
}

variable "apt_nomad_version" {
  type = string
    description = "Nomad version to install"
    default = "1.5.0-1"
}