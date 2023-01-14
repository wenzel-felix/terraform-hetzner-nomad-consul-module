provider "nomad" {
  address   = "http://${file("../certs/nomad_address")}:80"
  secret_id = trimspace(file("../certs/nomad_token"))
}

locals {
  NOMAD_PORT_http = "80"
  NOMAD_IP_http   = "10.0.0.3"
}

resource "nomad_job" "demo-webapp" {
  depends_on = [
    nomad_job.traefik
  ]
  jobspec = <<EOT
job "demo-webapp" {
  datacenters = ["dc1"]

  group "demo" {
    count = 4

    network {
      port  "http"{
        static = 8888
      }
    }

    service {
      name = "demo-webapp"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=Path(`/`)",
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "2s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo"
        network_mode = "host"
        args  = [
          "-listen", ":8888",
          "-text", "Hello World!",
        ]
      }
    }
  }
}
EOT
}

resource "nomad_job" "traefik" {
  jobspec = <<EOT
job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 8080
      }

      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.2"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }

      template {
        data = <<EOF
[entryPoints]
    [entryPoints.http]
    address = ":8080"
    [entryPoints.traefik]
    address = ":8081"

[api]
    dashboard = true
    insecure  = true

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
EOT
}