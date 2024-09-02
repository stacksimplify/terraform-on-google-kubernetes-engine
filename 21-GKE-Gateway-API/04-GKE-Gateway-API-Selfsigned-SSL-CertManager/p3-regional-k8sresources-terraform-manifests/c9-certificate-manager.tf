# Resource: Certificate manager certificate
resource "google_certificate_manager_certificate" "app1_cert" {
  location    = var.gcp_region1
  name        = "${local.name}-app1-${var.gcp_region1}-ssl-cert"
  description = "${local.name} Certificate Manager SSL Certificate"
  scope       = "DEFAULT"
  self_managed {
    pem_certificate = file("${path.module}/self-signed-ssl/app1.crt")
    pem_private_key = file("${path.module}/self-signed-ssl/app1.key")
  }
  labels = {
    env = local.environment
  }
}
