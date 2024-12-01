variable "hetzner_token" {
  type        = string
  description = "Hetzner Cloud API Token"
}

variable "hetzner_server_sku" {
  type        = string
  description = "Hetzner Cloud SKU for servers"
  default     = "cpx11"
}

variable "hetzner_client_sku" {
  type        = string
  description = "Hetzner Cloud SKU for clients"
  default     = "cpx11"
}

variable "virtual_network_cidr" {
  type        = string
  description = "CIDR of the virtual network"
  default     = "10.0.0.0/16"
}

variable "nomad_server_count" {
  type        = number
  description = "Number of servers to create"
  default     = 3
}

variable "nomad_client_count" {
  type        = number
  description = "Number of clients to create"
  default     = 1
}

variable "node_locations" {
  type        = list(string)
  description = "Hetzner Cloud Datacenter"
  default     = ["hel1", "fsn1", "nbg1"]
}

variable "enable_nomad_acls" {
  type        = bool
  description = "Bootstrap Nomad with ACLs"
  default     = true
}

variable "hetzner_network_zone" {
  type        = string
  description = "Hetzner Cloud Network Zone"
  default     = "eu-central"
}

variable "apt_consul_version" {
  type        = string
  description = "Consul version to install"
  default     = "1.15.0-1"
}

variable "apt_nomad_version" {
  type        = string
  description = "Nomad version to install"
  default     = "1.5.0-1"
}

variable "generate_ssh_key_file" {
  type        = bool
  description = "Defines whether the generated ssh key should be stored as local file."
  default     = false
}
