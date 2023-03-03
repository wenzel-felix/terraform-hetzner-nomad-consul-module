provider "nomad" {
  address   = "http://${file("../certs/nomad_address")}:80"
  secret_id = trimspace(file("../certs/nomad_token"))
}

resource "nomad_job" "demo-webapp" {
  depends_on = [
    nomad_job.traefik
  ]
  jobspec = file("jobs/demo-webapp.nomad")
  lifecycle {
    replace_triggered_by = [nomad_job.traefik]
  }
}

resource "nomad_job" "traefik" {
  jobspec = file("jobs/traefik.nomad")
}
