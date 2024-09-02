resource "google_compute_address" "static_ip" {
  name   = "${local.name}-my-regional-ip"
  region = var.gcp_region1
  network_tier = "STANDARD"
}

output "static_ip_address" {
  value = google_compute_address.static_ip.address
}

output "static_ip_name" {
  value = google_compute_address.static_ip.name
}