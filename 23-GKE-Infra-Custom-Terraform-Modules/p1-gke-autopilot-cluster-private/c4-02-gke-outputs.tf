# Terraform Outputs
output "gke_cluster_name" {
  description = "GKE cluster name"
  value = module.gke_cluster.gke_cluster_name
}

output "gke_cluster_location" {
  description = "GKE Cluster location"
  value = module.gke_cluster.gke_cluster_location
}

output "gke_cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  value = module.gke_cluster.gke_cluster_endpoint
}

output "gke_cluster_master_version" {
  description = "GKE Cluster master version"
  value = module.gke_cluster.gke_cluster_master_version
}
