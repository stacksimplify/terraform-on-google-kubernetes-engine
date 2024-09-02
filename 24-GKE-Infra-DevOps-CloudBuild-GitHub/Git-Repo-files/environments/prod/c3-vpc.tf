# Resource: VPC
resource "google_compute_network" "myvpc" {
  name = "${local.name}-vpc"
  auto_create_subnetworks = false   
}

# Resource: Subnet
resource "google_compute_subnetwork" "mysubnet" {
  name = "${local.name}-${var.gcp_region}-subnet"
  region = var.gcp_region
  network = google_compute_network.myvpc.id 
  private_ip_google_access = true
  ip_cidr_range = var.subnet_ip_range
  secondary_ip_range {
    range_name    = "kubernetes-pod-range"
    ip_cidr_range = var.pods_ip_range
  }
  secondary_ip_range {
    range_name    = "kubernetes-services-range"
    ip_cidr_range = var.services_ip_range
  }
}

# Terraform Outputs
output "vpc_id" {
  description = "VPC ID"
  value = google_compute_network.myvpc.id 
}

output "vpc_self_link" {
  description = "VPC Self Link"
  value = google_compute_network.myvpc.self_link
}

output "mysubnet_id" {
  description = "Subnet ID"
  value = google_compute_subnetwork.mysubnet.id 
}
