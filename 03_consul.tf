##################################################
# consul server cert
##################################################
resource "tls_private_key" "consul_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "consul_server" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.consul_server.private_key_pem

  dns_names = [
    "localhost",
    "server.dc1.consul",
    "medea.seankhliao.com",
  ]

  ip_addresses = [
    "127.0.0.1",
    "192.168.100.2",
    "65.21.73.144",
  ]

  subject {
    common_name  = "medea.seankhliao.com"
    organization = "medea / seankhliao"
  }
}
resource "tls_locally_signed_cert" "consul_server" {
  ca_key_algorithm   = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
  cert_request_pem   = tls_cert_request.consul_server.cert_request_pem

  validity_period_hours = 24 * 365

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

##################################################
# consul
##################################################
resource "null_resource" "medea_consul" {
  depends_on = [
    null_resource.medea,
  ]

  connection {
    host        = "medea.seankhliao.com"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
    agent       = false
  }

  provisioner "file" {
    destination = "/etc/systemd/system/consul.service"
    content     = <<-EOT
      [Unit]
      Description=Consul Agent
      Documentation=https://consul.io/docs/
      Requires=network-online.target
      After=network-online.target

      [Service]
      Restart=on-failure
      ExecStart=/usr/local/bin/consul agent -config-file /etc/consul/server.hcl
      ExecReload=/usr/bin/kill -HUP $MAINPID
      KillSignal=SIGINT

      [Install]
      WantedBy=multi-user.target
    EOT
  }
  provisioner "remote-exec" {
    inline = [
      "curl -Lo /tmp/consul.zip https://releases.hashicorp.com/consul/1.9.5/consul_1.9.5_linux_amd64.zip",
      "unzip -o /tmp/consul.zip consul -d /usr/local/bin",
      "systemctl daemon-reload",
      "systemctl enable consul",
      "rm -rf /etc/consul || true",
      "mkdir -p /etc/consul",
    ]
  }
  provisioner "file" {
    destination = "/etc/consul/ca.crt"
    content     = tls_self_signed_cert.ca.cert_pem
  }
  provisioner "file" {
    destination = "/etc/consul/server.key"
    content     = tls_private_key.consul_server.private_key_pem
  }
  provisioner "file" {
    destination = "/etc/consul/server.crt"
    content     = tls_locally_signed_cert.consul_server.cert_pem
  }
  provisioner "file" {
    destination = "/etc/consul/server.hcl"
    content     = <<-EOT
      bind_addr = "0.0.0.0"
      data_dir  = "/var/lib/consul"
      ports {
        http = -1
        https = 8501
        grpc = 8502
      }

      ca_file   = "/etc/consul/ca.crt"
      cert_file = "/etc/consul/server.crt"
      key_file  = "/etc/consul/server.key"

      verify_incoming = true
      verify_server_hostname = true

      leave_on_terminate = true

      disable_update_check = true

      server = true
      bootstrap_expect = 1

      client_addr = "0.0.0.0"

      ui_config {
        enabled = true
      }

      log_level = "INFO"
    EOT
  }
}
