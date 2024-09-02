# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.42.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.32"
    }      
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-demo1"    
  }  
}

