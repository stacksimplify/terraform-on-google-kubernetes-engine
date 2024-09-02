# Resource: Certificate Manager DNS Authorization
resource "google_certificate_manager_dns_authorization" "myapp1" {
  location    = var.gcp_region1
  name        = "${local.name}-myapp1-dns-authorization"
  description = "myapp1 dns authorization"
  domain      = "${local.mydomain}"
}

# Resource: Certificate manager certificate
resource "google_certificate_manager_certificate" "myapp1" {
  location    = var.gcp_region1
  name        = "${local.name}-myapp1-ssl-certificate"
  description = "${local.name} Certificate Manager SSL Certificate"
  scope       = "DEFAULT"
  labels = {
    env = "dev"
  }
  managed {
    domains = [
      google_certificate_manager_dns_authorization.myapp1.domain
      ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.myapp1.id
      ]
  }
}


# Resource: DNS record to be created in DNS zone for DNS Authorization
resource "google_dns_record_set" "myapp1_cname" {
  #project      = "kdaida123"
  managed_zone = "${local.dns_managed_zone}"
  name         = google_certificate_manager_dns_authorization.myapp1.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.myapp1.dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.myapp1.dns_resource_record[0].data]
}

