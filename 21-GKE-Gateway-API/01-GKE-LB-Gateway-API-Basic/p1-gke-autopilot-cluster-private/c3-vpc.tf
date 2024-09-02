# Resource: VPC
resource "google_compute_network" "myvpc" {
  name = "${local.name}-vpc"
  auto_create_subnetworks = false   
}

# Resource: Subnet
resource "google_compute_subnetwork" "mysubnet" {
  name = "${local.name}-${var.gcp_region1}-subnet"
  region = var.gcp_region1
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

# Resource: Regional Proxy-Only Subnet (Required for Regional Application Load Balancer)
resource "google_compute_subnetwork" "regional_proxy_subnet" {
  name             = "${local.name}-${var.gcp_region1}-regional-proxy-subnet"
  region           = var.gcp_region1
  ip_cidr_range    = "10.142.0.0/24"
  purpose          = "REGIONAL_MANAGED_PROXY"
  network          = google_compute_network.myvpc.id
  role             = "ACTIVE"
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

output "vpc_name" {
  description = "VPC Name"
  value = google_compute_network.myvpc.name 
}

output "mysubnet_id" {
  description = "Subnet ID"
  value = google_compute_subnetwork.mysubnet.id 
}

output "regional_proxy_subnet_id" {
  description = "Regional Proxy Subnet ID"
  value = google_compute_subnetwork.regional_proxy_subnet.id 
}


