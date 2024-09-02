---
title: GCP Google Kubernetes Engine GKE - Standard Public Cluster
description: Learn to deploy GCP GKE standard public cluster using Terraform
---

## Step-01: Introduction
1. Install kubectl cli
2. Create Terraform configs for GKE standard public cluster
3. Create GKE cluster using Terraform
4. Verify resources

## Step-02: Install kubectl CLI
```t
# Verify gcloud 
gcloud config configurations list

# Update gcloud
gcloud components update

# Install kubectl
gcloud components install kubectl
Observation:
1. Installs kubectl
2. Installs gke-gcloud-auth-plugin

# kubectl version commands
kubectl version --client
kubectl version
```

## Step-03: Create Cloud Storage Bucket and Update the bucket details in c1-versions.tf
### Step-03-01: Create Cloud Storage Bucket to Store Terraform State files
- **Name your bucket:** terraform-on-gcp-gke
- **Choose where to store your data:** 
  - **Region:** us-central1
- **Choose a storage class for your data:**  
  - **Set a default class:** Standard
- **Choose how to control access to objects:**  
  - **Prevent public access:** Enforce public access prevention on this bucket
  - **Access control:** uniform
- **Choose how to protect object data:** 
  - **Soft Delete:** leave to defaults
  - **Object versioning:** 90
  - **Expire noncurrent versions after:** 365
- Click on **CREATE**  

### Step-03-02: c1-versions.tf and Remote Backend
- [Terraform Remote Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.38.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster-public"    
  }
}

# Terraform Provider Block
provider "google" {
  project = var.gcp_project
  region = var.gcp_region1
}
```

## Step-04: c2-01-variables.tf
```hcl
# Input Variables
# GCP Project
variable "gcp_project" {
  description = "Project in which GCP Resources to be created"
  type = string
  default = "kdaida123"
}

# GCP Region
variable "gcp_region1" {
  description = "Region in which GCP Resources to be created"
  type = string
  default = "us-east1"
}

# GCP Compute Engine Machine Type
variable "machine_type" {
  description = "Compute Engine Machine Type"
  type = string
  default = "e2-small"
}


# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type = string
  default = "dev"
}

# Business Division
variable "business_divsion" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type = string
  default = "sap"
}
```

## Step-05: c2-02-local-values.tf
```hcl
# Define Local Values in Terraform
locals {
  owners = var.business_divsion
  environment = var.environment
  name = "${var.business_divsion}-${var.environment}"
  #name = "${local.owners}-${local.environment}"
  common_tags = {
    owners = local.owners
    environment = local.environment
  }
} 
```

## Step-06: c3-vpc.tf
```hcl
# Resource: VPC
resource "google_compute_network" "myvpc" {
  name = "${local.name}-vpc"
  auto_create_subnetworks = false   
}

# Resource: Subnet
resource "google_compute_subnetwork" "mysubnet" {
  name = "${local.name}-${var.gcp_region1}-subnet"
  region = var.gcp_region1
  ip_cidr_range = "10.128.0.0/20"
  network = google_compute_network.myvpc.id 
  private_ip_google_access = true
}
```

## Step-07: c4-firewallrules.tf
```hcl
# Firewall Rule: SSH
resource "google_compute_firewall" "fw_ssh" {
  name = "${local.name}-fwrule-allow-ssh22"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.myvpc.id 
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-tag"]
}
```

## Step-08: c5-01-gke-service-account.tf
```hcl
resource "google_service_account" "gke_sa" {
  account_id   = "${local.name}-gke-sa"
  display_name = "${local.name} GKE Service Account"
}
```

## Step-09: c5-02-gke-cluster.tf
```hcl
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
```

## Step-10: c5-03-gke-linux-nodepool.tf
```hcl
# Resource: GKE Node Pool 1
resource "google_container_node_pool" "nodepool_1" {
  name       = "${local.name}-node-pool-1"
  location   = var.gcp_region1
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = var.machine_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_sa.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    tags = [tolist(google_compute_firewall.fw_ssh.target_tags)[0]]
  }
}
```

## Step-11: c5-04-gke-outputs.tf
```hcl
# Terraform Outputs
output "gke_cluster_name" {
  description = "GKE cluster name"
  value = google_container_cluster.gke_cluster.name
}

output "gke_cluster_location" {
  description = "GKE Cluster location"
  value = google_container_cluster.gke_cluster.location
}

output "gke_cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  value = google_container_cluster.gke_cluster.endpoint
}

output "gke_cluster_master_version" {
  description = "GKE Cluster master version"
  value = google_container_cluster.gke_cluster.master_version
}
```

## Step-12: Execute Terraform Commands
```t
# Change Directory
cd p1-gke-public-cluster

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

## Step-13: Verify GCP GKE Resources
```t
# Verify GCP GKE Resources
1. GKE cluster
2. GKE Node pools

# Configure kubectl cli
gcloud container clusters get-credentials CLUSTER_NAME --region REGION --project PROJECT_ID
gcloud container clusters get-credentials hr-dev-gke-cluster --region us-central1 --project gcplearn9

# kubectl version client and server(cluster)
kubectl version 

# List Kubernetes Nodes
kubectl get nodes -o wide
```


