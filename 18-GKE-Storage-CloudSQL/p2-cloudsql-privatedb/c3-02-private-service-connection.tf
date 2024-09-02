## CONFIGS RELATED TO CLOUD SQL PRIVATE CONNECTION
# Resource: Reserve Private IP range for VPC Peering
resource "google_compute_global_address" "private_ip" {
  name          = "${local.name}-vpc-peer-privateip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.terraform_remote_state.gke.outputs.vpc_id
}


# Resource: Private Service Connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = data.terraform_remote_state.gke.outputs.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
  deletion_policy = "ABANDON" # After terraform destroy, destroy it manually
}
