# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = "${local.name}-gke-cluster-autopilot"
  location = var.gcp_region1

  # Autopilot Cluster
  enable_autopilot = true
   
  # Network
  network = google_compute_network.myvpc.self_link
  subnetwork = google_compute_subnetwork.mysubnet.self_link

  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = false

  # Private Cluster Configurations
  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ip_range
  }

  # IP Address Ranges
  ip_allocation_policy {
    #cluster_ipv4_cidr_block  = "10.1.0.0/21"
    #services_ipv4_cidr_block = "10.2.0.0/21"
    cluster_secondary_range_name = google_compute_subnetwork.mysubnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.mysubnet.secondary_ip_range[1].range_name
  }

  # Allow access to Kubernetes master API Endpoint
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "0.0.0.0/0"
      display_name = "entire-internet"
    }
  }
}


