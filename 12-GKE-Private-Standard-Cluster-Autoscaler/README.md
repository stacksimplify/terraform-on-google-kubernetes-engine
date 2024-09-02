---
title: GCP Google Kubernetes Engine GKE - Standard Private Cluster
description: Learn to deploy GCP GKE standard private cluster using Terraform
---

## Step-01: Introduction
1. Create Terraform configs for GKE standard private cluster
2. Configure Cluster Autoscaler (Nodepool autosclaing)
3. Execute Terraform Commands to GKE standard private cluster 
4. Verify resources

## Step-02: c1-versions.tf
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.42.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster-private"    
  }
}

# Terraform Provider Block
provider "google" {
  project = var.gcp_project
  region = var.gcp_region1
}
```

## Step-03: c2-01-variables.tf
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

## Step-04: c2-02-local-values.tf
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
## Step-05: c3-vpc.tf
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
```
## Step-06: c4-firewallrules.tf
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
## Step-07: c5-datasource.tf
```hcl
# Terraform Datasources
# Datasource: Get a list of Google Compute zones that are UP in a region
data "google_compute_zones" "available" { 
  status = "UP"   
}

# Output value
output "compute_zones" {
  description = "List of compute zones"
  value = data.google_compute_zones.available.names
}
```
## Step-08: c6-01-gke-service-account.tf
```hcl
resource "google_service_account" "gke_sa" {
  account_id   = "${local.name}-gke-sa"
  display_name = "${local.name} GKE Service Account"
}
```
## Step-09: c6-02-gke-cluster.tf
```hcl
# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = "${local.name}-gke-cluster"
  location = var.gcp_region1
  
  # Node Locations: Get from Datasource: google_compute_zones
  node_locations = data.google_compute_zones.available.names

  # Create the smallest possible default node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  
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
## Step-10: c6-03-gke-linux-nodepool.tf
```hcl
# Resource: GKE Node Pool 2
resource "google_container_node_pool" "linux_nodepool_1" {
  name       = "${local.name}-linux-nodepool-1"
  location   = var.gcp_region1
  cluster    = google_container_cluster.gke_cluster.name
  initial_node_count = 1 # the number of nodes to create in each zone
  autoscaling {
    min_node_count = 1
    max_node_count = 3
    location_policy = "ANY"  
  }
  node_config {  
    preemptible  = true
    machine_type = var.machine_type
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_sa.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    tags = [tolist(google_compute_firewall.fw_ssh.target_tags)[0]]
    disk_size_gb = 20
    disk_type = "pd-standard" # Supported pd-standard, pd-balanced or pd-ssd, default is pd-standard    
  }
}
```
## Step-11: c6-04-gke-outputs.tf
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

# Terraform Outputs: Linux NodePool
output "gke_linux_nodepool_1_id" {
  description = "GKE Linux Node Pool 1 ID"
  value = google_container_node_pool.linux_nodepool_1.id
}
output "gke_linux_nodepool_1_version" {
  description = "GKE Linux Node Pool 1 version"
  value = google_container_node_pool.linux_nodepool_1.version
}
```

## Step-12: c7-Cloud-NAT-Cloud-Router.tf
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

## Step-13: terraform.tfvars
```hcl
gcp_project     = "gcplearn9"
gcp_region1     = "us-central1"
machine_type    = "e2-medium"
environment     = "dev"
business_divsion = "hr"
subnet_ip_range  = "10.128.0.0/20"
pods_ip_range    = "10.1.0.0/21"
services_ip_range = "10.2.0.0/21"
master_ip_range  = "10.3.0.0/28"
```

## Step-14: Execute Terraform Commands
```t
# Change Directory
cd p1-gke-private-cluster-autoscaler

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

## Step-15: Verify GKE private cluster resources
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
Observation: 
1. Only private IPs will be associated with the GKE Nodes
```

## Step-16: Deploy Sample Application and Verify
```t
# Change Directory
cd p3-k8sresources-terraform-manifests

# Update c1-versions.tf
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-demo1"    
  }  

# Update c3-01-remote-state-datasource.tf
# Terraform Remote State Datasource
data "terraform_remote_state" "gke" {
  backend = "gcs"
  config = {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster-public"
  }  
}  

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

## Step-17: Verify Kubernetes Resources
```t
# List Nodes
kubectl get nodes -o wide

# List Pods
kubectl get pods -o wide
Observation: 
1. Pods should be deployed on the GKE node pool

# List Services
kubectl get svc
kubectl get svc -o wide
Observation:
1. We should see Load Balancer Service created

# Access Sample Application on Browser
http://<LOAD-BALANCER-IP>
```

## Step-18: Verify Kubernetes Resources via GCP console
1. Go to Services -> GCP -> Load Balancing -> Load Balancers
2. Verify Tabs
   - Description: Make a note of LB DNS Name
   - Instances
   - Health Checks
   - Listeners
   - Monitoring

## Step-19: Test Cluster Autoscaler
```t
# List Kubernetes Pods
kubectl get pods -o wide

# List Kubernetes Nodes
kubectl get nodes

# List Kubernetes Deployments
kubectl get deploy

# Scale the Deployment
kubectl scale deployment myapp1-deployment --replicas=100

# List Kubernetes Pods
kubectl get pods
Observation: 
1. Few Pods will be in pending state

# List Nodes
kubectl get nodes
Observation:
1. Nodes will be autoscaled
2. new nodes will be created.
```

## Step-19: Clean-Up 
```t
# Delete Kubernetes  Resources
cd p3-k8sresources-terraform-manifests
terraform apply -destroy -auto-approve
rm -rf .terraform* 

# Delete GCP GKE Cluster (DONT DELETE NOW)
cd 12-GKE-Private-Standard-Cluster/p1-gke-private-cluster-autoscaler/
terraform apply -destroy -auto-approve
rm -rf .terraform* 
```