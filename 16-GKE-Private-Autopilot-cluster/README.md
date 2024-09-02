---
title: GCP Google Kubernetes Engine GKE - Autopilot Private Cluster
description: Learn to deploy GCP GKE Autopilot private cluster using Terraform
---

## Step-01: Introduction
1. Create Terraform configs for GKE Autopilot cluster
2. Deploy and Verify cluster resources
3. Deploy sample application and test
- [Autopilot Clusters - Resource Planning](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-resource-requests#defaults)

## Step-02: GKE Autopilot cluster
- **Folder Location:** p1-gke-autopilot-cluster-private
### Step-02-01: c1-versions.tf
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
    prefix = "dev/gke-cluster-private-autopilot"    
  }
}

# Terraform Provider Block
provider "google" {
  project = var.gcp_project
  region = var.gcp_region1
}
```
### Step-02-02: c2-01-variables.tf
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

# CIDR IP Ranges
variable "subnet_ip_range" {
  description = "Subnet IP range"
  type = string
  default = "10.129.0.0/20"
}

variable "pods_ip_range" {
  description = "Kubernetes Pods IP range"
  type = string
  default = "10.11.0.0/21"
}

variable "services_ip_range" {
  description = "Kubernetes Services IP range"
  type = string
  default = "10.12.0.0/21"
}

variable "master_ip_range" {
  description = "Kubernetes Master IP range"
  type = string
  default = "10.13.0.0/28"
}
```
### Step-02-03: c2-02-local-values.tf
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
### Step-02-04: c3-vpc.tf
```hcl
# Resource: VPC
resource "google_compute_network" "myvpc" {
  name = "${local.name}-vpc"
  auto_create_subnetworks = false   
}

# Resource: Subnet
resource "google_compute_subnetwork" "mysubnet" {
  name = "${var.gcp_region1}-subnet"
  region = var.gcp_region1
  network = google_compute_network.myvpc.id 
  private_ip_google_access = true
  ip_cidr_range = var.subnet_ip_range
  secondary_ip_range {
    range_name    = "kubernetes-pod-range"
    ip_cidr_range = var.pods_ip_range
  }
  secondary_ip_range {
    range_name    = "kubernetes-services-range"
    ip_cidr_range = var.services_ip_range
  }
}

# Terraform Outputs
output "vpc_id" {
  description = "VPC ID"
  value = google_compute_network.myvpc.id 
}

output "vpc_self_link" {
  description = "VPC Self Link"
  value = google_compute_network.myvpc.self_link
}

output "mysubnet_id" {
  description = "Subnet ID"
  value = google_compute_subnetwork.mysubnet.id 
}

```
### Step-02-05: c4-01-gke-cluster.tf
```hcl
# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = "${local.name}-gke-cluster-autopilot"
  location = var.gcp_region1

  # Autopilot Cluster
  enable_autopilot = true
   
  # Network
  network = google_compute_network.myvpc.self_link
  subnetwork = google_compute_subnetwork.mysubnet.self_link

  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = false

  # Private Cluster Configurations
  private_cluster_config {
    enable_private_endpoint = false
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
      cidr_block = "0.0.0.0/0"
      display_name = "entire-internet"
    }
  }
}
```
### Step-02-06: c4-02-gke-outputs.tf
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
### Step-02-07: c5-Cloud-NAT-Cloud-Router.tf
```hcl
# Resource: Cloud Router
resource "google_compute_router" "cloud_router" {
  name    = "${local.name}-${var.gcp_region1}-cloud-router"
  network = google_compute_network.myvpc.id
  region  = var.gcp_region1
}

# Resource: Cloud NAT
resource "google_compute_router_nat" "cloud_nat" {
  name   = "${local.name}-${var.gcp_region1}-cloud-nat"
  router = google_compute_router.cloud_router.name
  region = google_compute_router.cloud_router.region
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ALL"
  }
}
```
### Step-02-08: terraform.tfvars
```hcl
gcp_project     = "gcplearn9"
gcp_region1     = "us-central1"
environment     = "dev"
business_divsion = "hr"
subnet_ip_range  = "10.128.0.0/20"
pods_ip_range    = "10.1.0.0/21"
services_ip_range = "10.2.0.0/21"
master_ip_range  = "10.3.0.0/28"
```
### Step-02-09: Execute Terraform Commands and Verify
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

# Verify GKE resources
1. GKE cluster
2. GKE Cluster Details

# Configure kubectl cli
gcloud container clusters get-credentials hr-dev-gke-cluster-autopilot --region us-central1 --project gcplearn9

# List Kubernetes Nodes
kubectl get nodes
Observation:
1. As it is a autopilot cluster, no k8s nodes created initially
2. k8s Nodes will be created only when we deploy k8s resources
```


## Step-03: Deploy sample Application
- **Sample App: YAML Manifests:** p2-k8sresources-yaml
- **Sample App: Terraform Manifests:** p3-k8sresources-terraform-manifests
### Step-03-01: c1-versions.tf
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.37.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.31"
    }      
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-demo1"    
  }  
}
```
### Step-03-02: c3-01-remote-state-datasource.tf
```hcl
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

```
### Step-03-03:  c4-kubernetes-deployment.tf
```hcl
# Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp1" {
  metadata {
    name = "myapp1-deployment"
    labels = {
      app = "myapp1"
    }
  } 
 
  spec {
    replicas = 2
    #replicas = 10

    selector {
      match_labels = {
        app = "myapp1"
      }
    }

    template {
      metadata {
        labels = {
          app = "myapp1"
        }
      }

      spec {
        container {
          image = "ghcr.io/stacksimplify/kubenginx:1.0.0"
          name  = "myapp1-container"
          port {
            container_port = 80
          }
          # Kubernetes Resources: Requests and Limits
          resources {
            limits = {
              cpu    = "400m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
          }
        }
      }
    }
}
```
### Step-03-04: Execute Terraform Commands and Verify
```t
# Change Directory
cd p3-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Configure kubectl cli
gcloud container clusters get-credentials hr-dev-gke-cluster-autopilot --region us-central1 --project gcplearn9

# List Kubernetes Nodes
kubectl get nodes

# List Kubernetes Deployments
kubectl get deploy

# List Kubernetes Pods
kubectl get pods

# List Kubernetes Services
kubectl get svc
```

## Step-04: Clean Up: DELETE P3 Project
```t
# Delete Kubernetes  Resources
cd p3-k8sresources-terraform-manifests
terraform apply -destroy -auto-approve
rm -rf .terraform* 
```

## Step-05: DONT DELETE P1 Project
```t
# Project P1: p1-gke-autopilot-cluster-private
1. Dont delete GKE cluster, we will use it in next demo
```


