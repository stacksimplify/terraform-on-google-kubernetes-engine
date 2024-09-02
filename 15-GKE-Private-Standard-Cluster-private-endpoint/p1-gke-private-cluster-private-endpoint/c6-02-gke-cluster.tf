# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = "${local.name}-gke-cluster"
  location = var.gcp_region1
  
  # Node Locations: Get from Datasource: google_compute_zones
  node_locations = data.google_compute_zones.available.names

  # Create the smallest possible default node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # Network
  network = google_compute_network.myvpc.self_link
  subnetwork = google_compute_subnetwork.mysubnet.self_link

  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = false

  # Private Cluster Configurations
  private_cluster_config {
    enable_private_endpoint = true # Enable private endpoint 
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
      cidr_block = "10.128.15.15/32"
      display_name = "Access only from Bastion VM whose IP is 10.128.15.15"
    }
  }
}

/* 
Important Note-1: It is recommended that node pools be created and 
managed as separate resources as in the example above. 
This allows node pools to be added and removed without recreating the cluster. 
Node pools defined directly in the google_container_cluster resource cannot be 
removed without re-creating the cluster.

Important Note-2: 
We can't create a cluster with no node pool defined, but we want to only use
separately managed node pools. So we create the smallest possible default
node pool and immediately delete it.

Important Note-3: 
Google recommends custom service accounts that have cloud-platform scope and 
permissions granted via IAM Roles.
*/

