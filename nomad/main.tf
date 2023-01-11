provider "nomad" {
  address = "http://${file("../tmp/nomad_address")}:4646"
  secret_id = trimspace(file("../tmp/nomad_token"))
}