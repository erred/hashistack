##################################################
# nomad server cert
##################################################
resource "tls_private_key" "nomad_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "nomad_server" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.nomad_server.private_key_pem

  dns_names = [
    "localhost",
    "server.global.nomad",
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
resource "tls_locally_signed_cert" "nomad_server" {
  ca_key_algorithm   = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
  cert_request_pem   = tls_cert_request.nomad_server.cert_request_pem

  validity_period_hours = 24 * 365

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

##################################################
# nomad
##################################################
resource "null_resource" "medea_nomad" {
  depends_on = [
    null_resource.medea,
  ]

  connection {
    host        = "medea.seankhliao.com"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
    agent       = false
  }

  provisioner "file" {
    destination = "/etc/systemd/system/nomad.service"
    content     = <<-EOT
      [Unit]
      Description=nomad server
      Documentation=https://www.nomadproject.io/docs/agent/
      Requires=network-online.target
      After=network-online.target

      [Service]
      Restart=on-failure
      ExecStart=/usr/local/bin/nomad agent -config /etc/nomad/server.hcl
      ExecReload=/usr/bin/kill -HUP $MAINPID
      KillSignal=SIGINT

      [Install]
      WantedBy=multi-user.target
    EOT
  }
  provisioner "remote-exec" {
    inline = [
      "curl -Lo /tmp/nomad.zip https://releases.hashicorp.com/nomad/1.1.0/nomad_1.1.0_linux_amd64.zip",
      "unzip -o /tmp/nomad.zip nomad -d /usr/local/bin",
      "systemctl daemon-reload",
      "systemctl enable nomad",
      "rm -rf /etc/nomad || true",
      "mkdir -p /etc/nomad",
    ]
  }
  provisioner "file" {
    destination = "/etc/nomad/ca.crt"
    content     = tls_self_signed_cert.ca.cert_pem
  }
  provisioner "file" {
    destination = "/etc/nomad/server.key"
    content     = tls_private_key.nomad_server.private_key_pem
  }
  provisioner "file" {
    destination = "/etc/nomad/server.crt"
    content     = tls_locally_signed_cert.nomad_server.cert_pem
  }
  provisioner "file" {
    destination = "/etc/nomad/server.hcl"
    content     = <<-EOT
      bind_addr = "0.0.0.0"
      data_dir  = "/var/lib/nomad"

      tls {
        http = true
        rpc  = true

        ca_file   = "/etc/nomad/ca.crt"
        cert_file = "/etc/nomad/server.crt"
        key_file  = "/etc/nomad/server.key"

        verify_server_hostname = true
        verify_https_client    = true
      }

      leave_on_interrupt = true
      leave_on_terminate = true

      disable_update_check = true

      server {
        enabled = true
        bootstrap_expect = 1
      }

      client {
        enabled = true
      }

      log_level = "INFO"
    EOT
  }
}
