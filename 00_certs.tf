##################################################
# ca certs
##################################################
resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm     = tls_private_key.ca.algorithm
  private_key_pem   = tls_private_key.ca.private_key_pem
  is_ca_certificate = true

  validity_period_hours = 24 * 365 * 10

  allowed_uses = [
    "cert_signing",
  ]

  subject {
    common_name  = "medea.seankhliao.com"
    organization = "medea / seankhliao"
  }
}
resource "local_file" "ca_cert" {
  content  = tls_self_signed_cert.ca.cert_pem
  filename = "${path.root}/out/ca.crt"
}


##################################################
# client cert
##################################################
resource "tls_private_key" "nomad_client" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}
resource "local_file" "nomad_client_key" {
  content  = tls_private_key.nomad_client.private_key_pem
  filename = "${path.root}/out/client.key"
}

resource "tls_cert_request" "nomad_client" {
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.nomad_client.private_key_pem

  subject {
    common_name  = "eevee.seankhliao.com"
    organization = "medea / seankhliao"
  }
}
resource "tls_locally_signed_cert" "nomad_client" {
  ca_key_algorithm   = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
  cert_request_pem   = tls_cert_request.nomad_client.cert_request_pem

  validity_period_hours = 24 * 365

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}
resource "local_file" "nomad_client_cert" {
  content  = tls_locally_signed_cert.nomad_client.cert_pem
  filename = "${path.root}/out/client.crt"
}
