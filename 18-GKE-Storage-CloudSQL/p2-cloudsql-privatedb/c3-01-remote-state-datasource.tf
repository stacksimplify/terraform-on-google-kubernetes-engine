# Terraform Remote State Datasource
data "terraform_remote_state" "gke" {
  backend = "gcs"
  config = {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster-private-autopilot"
  }  
}

output "p1_vpc_id" {
  value = data.terraform_remote_state.gke.outputs.vpc_id
}

output "p1_vpc_self_link" {
  value = data.terraform_remote_state.gke.outputs.vpc_self_link
}

output "p1_mysubnet_id" {
  value = data.terraform_remote_state.gke.outputs.mysubnet_id
}
