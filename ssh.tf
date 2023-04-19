resource "local_file" "private_key" {
  count           = var.generate_ssh_key_file ? 1 : 0
  content         = tls_private_key.machines.private_key_openssh
  filename        = "${path.root}/machines.pem"
  file_permission = "0600"
}

resource "tls_private_key" "machines" {
  algorithm = "RSA"
}

resource "hcloud_ssh_key" "default" {
  name       = "default"
  public_key = tls_private_key.machines.public_key_openssh
}