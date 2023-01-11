provider "nomad" {
  address = "http://${file("../tmp/nomad_address")}:80"
  secret_id = trimspace(file("../tmp/nomad_token"))
}

resource "nomad_job" "app" {
  jobspec = <<EOT
job "foo" {
  datacenters = ["dc1"]
  type        = "service"
  group "foo" {
    task "foo" {
      driver = "raw_exec"
      config {
        command = "/bin/sleep"
        args    = ["1"]
      }

      resources {
        cpu    = 20
        memory = 10
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }
}
EOT
}