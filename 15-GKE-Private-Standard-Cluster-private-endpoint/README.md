---
title: GCP Google Kubernetes Engine GKE - Standard Private Cluster with Private endpoint
description: Learn to deploy GCP GKE standard private cluster with private endpoint using Terraform
---

## Step-01: Introduction
1. Create Terraform configs for GKE standard private cluster with private endpoint
2. Deploy and Verify GKE standard private cluster with private endpoint 
3. Create Bastion VM Instance
4. Connect to VM Instance using IAP (Identity Aware proxy)
5. Upload the Sample app (p3-k8sresources-terraform-manifests) to Bastion VM
6. Deploy sample using bastion VM to GKE Cluster
7. IN SHORT, NO PUBLIC ACCESS TO GKE CLUSTER ANYWHERE

## Step-02: c1-versions.tf
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
    prefix = "dev/gke-cluster-private"    
  }
}

# Terraform Provider Block
provider "google" {
  project = var.gcp_project
  region = var.gcp_region1
}
```

## Step-03: c4-firewallrules.tf
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
  #source_ranges = ["0.0.0.0/0"]
  source_ranges = ["35.235.240.0/20"] # IAP IP Range
  target_tags   = ["ssh-tag"]
}

# 1. Allows ingress traffic from the IP range 35.235.240.0/20
# 2. This range contains all IP addresses that IAP uses for TCP forwarding.
# 3. Allows connections to port 22 that you want to be accessible by using IAP TCP forwarding.
```

## Step-04: c6-02-gke-cluster.tf
- Change this **`enable_private_endpoint = true`** to true
```hcl
  # Private Cluster Configurations
  private_cluster_config {
    enable_private_endpoint = true # Enable private endpoint 
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ip_range
  }
```
## Step-05: c6-03-gke-linux-nodepool.tf
- comment **`#tags = [tolist(google_compute_firewall.fw_ssh.target_tags)[0]]`**
```hcl
# Resource: GKE Node Pool 
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
    #tags = [tolist(google_compute_firewall.fw_ssh.target_tags)[0]]
    disk_size_gb = 20
    disk_type = "pd-standard" # Supported pd-standard, pd-balanced or pd-ssd, default is pd-standard    
  }
}

```
## Step-06: c8-bastion-vm.tf
```hcl
# Resource Block: Reserver Internal IP Address for Bastion Host
resource "google_compute_address" "bastion_internal_ip" {
  name         = "${local.name}-bastion-internal-ip"
  description  = "Internal IP address reserved for Bastion VM"
  address_type = "INTERNAL"
  region       = var.gcp_region1
  subnetwork   = google_compute_subnetwork.mysubnet.id 
  address      = "10.128.15.15" # Use subnet slicer to understand better https://www.davidc.net/sites/default/subnets/subnets.html
}

# COPY FROM terraform-on-google-kubernetes-engine/03-Terraform-Language-Basics/terraform-manifests/c5-vminstance.tf and Update as needed
# Resource Block: Create a single Compute Engine instance
resource "google_compute_instance" "bastion" {
  name         = "${local.name}-bastion-vm"
  machine_type = var.machine_type
  zone         = "us-central1-a"
  tags        = [tolist(google_compute_firewall.fw_ssh.target_tags)[0]]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.mysubnet.id 
    network_ip = google_compute_address.bastion_internal_ip.address
  }
  metadata_startup_script = <<-EOT
      #!/bin/bash
      sudo apt update
      sudo apt install -y telnet
      sudo apt-get install -y kubectl
      sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
      sudo apt update
      sudo apt install -y gnupg software-properties-common
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt update
      sudo apt install -y terraform
    EOT
}
```
## Step-07: Execute Terraform Commands
```t
# Change Directory
cd p1-gke-private-cluster-private-endpoint

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

## Step-08: Verify GKE private cluster resources
```t
# Verify GCP GKE Resources
1. GKE cluster
2. GKE Node pools
3. Verify bastion VM
```

## Step-09: Copy Terraform Files to Bastion Host
```t
# Change Directory
cd p3-k8sresources-terraform-manifests

### NOTE: Update below two files as per your environment
1. c1-versions.tf
2. c3-01-remote-state-datasource.tf

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

# Change Directory
cd 15-GKE-Private-Standard-Cluster-private-endpoint

# Copy files to Bastion VM
gcloud compute scp --recurse p3-k8sresources-terraform-manifests "hr-dev-bastion-vm:/tmp" --zone "us-central1-a" --tunnel-through-iap --project "gcplearn9"
```

## Step-10: Connect to Bastion VM and Verify
```t
# Connect to bastion VM
gcloud compute ssh --zone "us-central1-a" "hr-dev-bastion-vm" --tunnel-through-iap --project "gcplearn9"

# Verify installed software
gcloud version
kubectl version 
terraform version

# Configure gcloud cli with user
gcloud config configurations list
gcloud auth login
gcloud config configurations list
gcloud config list

# Set Project
gcloud config set project PROJECT_ID
gcloud config set project gcplearn9

# Configure kubectl cli
gcloud container clusters get-credentials hr-dev-gke-cluster --region us-central1 --project gcplearn9

# List Kubernetes Nodes
kubectl get nodes

# These credentials will be used by any library that requests Application Default Credentials (ADC).
gcloud auth application-default login

# Change Directory
cd /tmp/p3-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

## Step-11: Verify Kubernetes Resources
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
curl http://<LOAD-BALANCER-IP>
```

## Step-12: SSH to GKE Node VMs
- Key flag to learn here is **`--internal-ip`**
```t
# List Compute VM Instances
gcloud compute instances list

## SSH to GKE Node VM
gcloud compute ssh --zone "ZONE" "VM-NAME" --internal-ip  --project "gcplearn9"
gcloud compute ssh --zone "us-central1-b" "gke-hr-dev-gke-clust-hr-dev-linux-nod-50d31441-2s7c" --internal-ip  --project "gcplearn9"
exit
```

## Step-13: Clean-Up
```t
# Delete Kubernetes  Resources
cd p3-k8sresources-terraform-manifests
terraform apply -destroy -auto-approve
rm -rf .terraform* 
exit

# Delete GCP GKE Cluster
cd p1-gke-private-cluster-private-endpoint
terraform apply -destroy -auto-approve
rm -rf .terraform* 
```
