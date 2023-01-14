job "demo-webapp" {
  datacenters = ["dc1"]

  group "demo" {
    count = 1

    network {
      port "http" {
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
        image        = "hashicorp/http-echo"
        network_mode = "host"
        args = [
          "-listen", ":8888",
          "-text", "Hello World!",
        ]
      }
    }
  }
}