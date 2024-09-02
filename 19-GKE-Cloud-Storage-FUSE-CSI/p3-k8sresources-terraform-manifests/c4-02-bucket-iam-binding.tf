# Datasource: Get Project Information
data "google_project" "project" {
}

# Outputs
output "project_number" {
  value = data.google_project.project.number
}

# Resource: Cloud Storage Bucket IAM Binding
resource "google_storage_bucket_iam_binding" "iam_binding" {
  bucket = google_storage_bucket.my_bucket.name
  role   = "roles/storage.objectUser"
  members = [
    "principal://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.gcp_project}.svc.id.goog/subject/ns/${kubernetes_namespace.myns.metadata[0].name}/sa/${kubernetes_service_account.mysa.metadata[0].name}"
  ]
}