# Terraform Remote State Datasource
data "terraform_remote_state" "gke" {
  backend = "gcs"
  config = {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster-private-autopilot"
  }  
}

output "p1_gke_cluster_name" {
  value = data.terraform_remote_state.gke.outputs.gke_cluster_name
}

output "p1_gke_cluster_location" {
  value = data.terraform_remote_state.gke.outputs.gke_cluster_location
}


# Terraform Remote State Datasource - Remote Backend GCP Cloud Storage Bucket
data "terraform_remote_state" "cloudsql" {
  backend = "gcs"
  config = {
    bucket = "terraform-on-gcp-gke"
    prefix = "cloudsql/privatedb"
  }
}

output "p2_cloudsql_privateip" {
  description = "Cloud SQL Database Private IP"
  value = data.terraform_remote_state.cloudsql.outputs.cloudsql_db_private_ip
}

output "p2_cloudsql_mydb_schema" {
  value = data.terraform_remote_state.cloudsql.outputs.mydb_schema
}

output "p2_cloudsql_mydb_user" {
  value = data.terraform_remote_state.cloudsql.outputs.mydb_user
}

output "p2_cloudsql_mydb_password" {
  value = data.terraform_remote_state.cloudsql.outputs.mydb_password
  sensitive = true
}