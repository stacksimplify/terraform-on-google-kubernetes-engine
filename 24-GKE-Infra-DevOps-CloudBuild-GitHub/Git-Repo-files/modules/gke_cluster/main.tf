# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = var.cluster_name
  location = var.gcp_region

  # Autopilot Cluster
  enable_autopilot = var.autopilot_enabled
   
  # Network
  network = var.network
  subnetwork = var.subnetwork

  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = var.deletion_protection

  # Private Cluster Configurations
  private_cluster_config {
    enable_private_endpoint = var.enable_private_endpoint
    enable_private_nodes    = var.enable_private_nodes
    master_ipv4_cidr_block  = var.master_ip_range
  }

  # IP Address Ranges
  ip_allocation_policy {
    cluster_secondary_range_name = var.pods_ip_range
    services_secondary_range_name = var.services_ip_range
  }

  # Allow access to Kubernetes master API Endpoint
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = var.master_authorized_ip_range
      display_name = var.master_authorized_ip_range_name
    }
  }

/*
  # Add Resource labels
  resource_labels = {
    team = "frontend"
  }
*/  
}


