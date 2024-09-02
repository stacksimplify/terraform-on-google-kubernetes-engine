---
title: GCP Google Cloud Platform - Create GKE Custom Terraform Module
description: Learn to implement GKE Custom Terraform Module
---

## Step-01: Introduction
- Create a GKE Cluster custom Terraform Module (modules/gke_cluster)
- Use the GKE cluster custom terraform module to create GKE cluster (p1-gke-autopilot-cluster-private)


## Step-02: Terraform GKE custom module
- **Folder Path:** modules/gke_cluster
### Step-02-01: versions.tf
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.40.0"
    }
  }
}
```

### Step-02-02: variables.tf
```hcl
# Input Variables
# GCP Project
variable "gcp_project" {
  description = "Project in which GCP Resources to be created"
  type = string
  default = ""
}

# GCP Region
variable "gcp_region" {
  description = "Region in which GCP Resources to be created"
  type = string
  default = ""
}


# GKE Cluster Variables
variable "cluster_name" {
  description = "GKE Cluster name"
  type = string
  default = ""
}

variable "autopilot_enabled" {
  description = "GKE Cluster Type: Standard or Autopilot"
  type = bool 
  default = true 
}

variable "network" {
  description = "Network to deploy to. Only one of network or subnetwork should be specified."
  type        = string
  default     = ""
}

variable "subnetwork" {
  description = "Subnet to deploy to. Only one of network or subnetwork should be specified."
  type        = string
  default     = ""
}

variable "enable_private_endpoint" {
  description = "GKE Cluster: enable_private_endpoint"
  type = bool 
  default = false 
}

variable "enable_private_nodes" {
  description = "GKE Cluster: enable_private_nodes"
  type = bool 
  default = true
}

variable "deletion_protection" {
  description = "GKE Cluster: deletion_protection"
  type = bool 
  default = true 
}


# CIDR IP Ranges
variable "subnet_ip_range" {
  description = "Subnet IP range"
  type = string
  default = ""
}

variable "pods_ip_range" {
  description = "Kubernetes Pods IP range"
  type = string
  default = ""
}

variable "services_ip_range" {
  description = "Kubernetes Services IP range"
  type = string
  default = ""
}

variable "master_ip_range" {
  description = "Kubernetes Master IP range"
  type = string
  default = ""
}

# master_authorized_networks_config
variable "master_authorized_ip_range" {
  description = "Allowed master_authorized_networks CIDR Block"
  type = string
  default = ""
}

variable "master_authorized_ip_range_name" {
  description = "Name of master_authorized_networks CIDR Block"
  type = string
  default = ""
}
```

### Step-02-03: main.tf
```hcl
# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = var.cluster_name
  location = var.gcp_region

  # Autopilot Cluster
  enable_autopilot = var.autopilot_enabled
   
  # Network
  network = var.network
  subnetwork = var.subnetwork

  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = var.deletion_protection

  # Private Cluster Configurations
  private_cluster_config {
    enable_private_endpoint = var.enable_private_endpoint
    enable_private_nodes    = var.enable_private_nodes
    master_ipv4_cidr_block  = var.master_ip_range
  }

  # IP Address Ranges
  ip_allocation_policy {
    cluster_secondary_range_name = var.pods_ip_range
    services_secondary_range_name = var.services_ip_range
  }

  # Allow access to Kubernetes master API Endpoint
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = var.master_authorized_ip_range
      display_name = var.master_authorized_ip_range_name
    }
  }
/*
  # Add Resource labels
  resource_labels = {
    team = "frontend"
  }
*/  
}
```

### Step-02-04: outputs.tf
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

## Step-03: Call the Custom GKE Terraform Module
- **Folder Path:** p1-gke-autopilot-cluster-private
### Step-03-01: NO CHANGES
1. c1-versions.tf: Review cloud storage buckets
2. c2-01-variables.tf
3. c2-02-local-values.tf
4. c3-vpc.tf
5. c5-Cloud-NAT-Cloud-Router.tf
6. terraform.tfvars

### Step-03-02: c4-01-gke-cluster.tf
```hcl
# Module: GKE Cluster
module "gke_cluster" {
  source = "../modules/gke_cluster"
  cluster_name = "${local.name}-gke-cluster-autopilot"
  gcp_region = var.gcp_region
  
  # Autopilot Cluster
  autopilot_enabled = true

  # Network
  network = google_compute_network.myvpc.self_link
  subnetwork = google_compute_subnetwork.mysubnet.self_link

  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = false

  # Private Cluster Configurations
  enable_private_endpoint = false
  enable_private_nodes    = true
  master_ip_range  = var.master_ip_range

  # IP Address Ranges
  pods_ip_range = google_compute_subnetwork.mysubnet.secondary_ip_range[0].range_name
  services_ip_range = google_compute_subnetwork.mysubnet.secondary_ip_range[1].range_name

  # Allow access to Kubernetes master API Endpoint
  master_authorized_ip_range = "0.0.0.0/0"
  master_authorized_ip_range_name = "entire-internet"
}
```
### Step-03-03: c4-02-gke-outputs.tf
```hcl
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
```

### Step-03-04: Execute Terraform Commands
```t
# Change Directory
cd p1-gke-autopilot-cluster-private

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```
### Step-03-05: Verify Resources
```t
# Configure kubectl cli
gcloud container clusters get-credentials CLUSTER-NAME --region REGION --project PROJECT-ID
gcloud container clusters get-credentials hr-dev-gke-cluster-autopilot --region us-central1 --project gcplearn9

# Get Kubernetes versions
kubectl versions
Observation: If server version displayed, that means kubectl cli configured successfully to connect to GKE cluster
## Output
Client Version: v1.29.7
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: v1.29.6-gke.1254000

# List Kubernetes Nodes
kubectl get nodes
Observation: For auto-pilot clusters "No resources found" will be displayed if no workloads are configured

# Get Kubernetes cluster-info
kubectl cluster-info

# List all Kubernetes Namespaces
kubectl get all --all-namespaces

# List Kubernetes Pods from kube-system namespace
kubectl get pods -n kube-system
```

### Step-03-06: Clean-Up
```t
# Change Directory
cd p1-gke-autopilot-cluster-private

# Terraform Destroy
terraform apply -destroy -auto-approve
```
