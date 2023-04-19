resource "hcloud_load_balancer" "load_balancer" {
  name               = "nomad-load-balancer"
  load_balancer_type = "lb11"
  location           = "hel1"
}

resource "hcloud_load_balancer_network" "load_balancer" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id       = hcloud_network.network.id
}

resource "hcloud_load_balancer_service" "load_balancer_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 4646
  http {
    sticky_sessions = true
  }
  health_check {
    protocol = "http"
    port     = 4646
    interval = 10
    timeout  = 5
    retries  = 3
    http {
      path = "/v1/status/leader"
      status_codes = [
        "2??",
        "3??",
      ]
    }
  }
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  depends_on = [
    hcloud_load_balancer_network.load_balancer
  ]
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  label_selector   = "nomad-server"
  use_private_ip   = true
}

resource "local_file" "load_balancer_ip" {
  content  = hcloud_load_balancer.load_balancer.ipv4
  filename = "${path.root}/certs/nomad_address"
}