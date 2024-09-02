# Random suffix
resource "random_id" "bucket_name_suffix" {
  byte_length = 4
}

# Resource: Cloud Storage Bucket
resource "google_storage_bucket" "my_bucket" {
  name     = "${local.name}-gcs-fuse-${random_id.bucket_name_suffix.hex}"
  location = "US"  # Setting this to "US" makes it a multi-regional bucket
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  force_destroy = true 
}

# Outputs
output "my_bucket" {
  value = google_storage_bucket.my_bucket.name
}