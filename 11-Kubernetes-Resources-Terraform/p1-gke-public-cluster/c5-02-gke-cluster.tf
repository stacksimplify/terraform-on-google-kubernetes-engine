# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = "${local.name}-gke-cluster"
  location = var.gcp_region1

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  # Network
  network = google_compute_network.myvpc.self_link
  subnetwork = google_compute_subnetwork.mysubnet.self_link
  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = false
}


/* 
Important Notes-1: It is recommended that node pools be created and 
managed as separate resources as in this. 
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
