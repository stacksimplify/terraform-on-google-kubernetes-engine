---
title: GCP GKE - CloudSQL Private Database used in GKE workloads
description: Learn to implement CloudSQL Private Database using Terraform and use it in Application deployed in GCP GKE
---

## Step-01: Introduction
- **Terraform Project-1:** GKE Autopilot private cluster
- **Terraform Project-2:** Cloud SQL MySQL Database with Private Endpoint
- **Terraform Project-3:** Use the Cloud SQL MySQL Database as storage for our User Management Web Application

## Step-02: Project-2: p2-cloudsql-privatedb
### Step-02-01: c1-versions.tf
- Add the `backend block` which is a Google Cloud Storage bucket
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
    prefix = "cloudsql/privatedb"
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

# Cloud SQL Database version
variable "cloudsql_database_version" {
  description = "Cloud SQL MySQL DB Database version"
  type = string
  default = "MYSQL_8_0"
}
```

### Step-02-03: terraform.tfvars
```hcl
gcp_project     = "gcplearn9"
gcp_region1     = "us-central1"
environment     = "dev"
business_divsion = "hr"
cloudsql_database_version = "MYSQL_8_0"
```

### Step-02-04: c2-02-local-values.tf
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

### Step-02-05: c3-01-remote-state-datasource.tf
```hcl
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
```
### Step-02-06: c3-02-private-service-connection.tf
```hcl
## CONFIGS RELATED TO CLOUD SQL PRIVATE CONNECTION
# Resource: Reserve Private IP range for VPC Peering
resource "google_compute_global_address" "private_ip" {
  name          = "${local.name}-vpc-peer-privateip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.terraform_remote_state.gke.outputs.vpc_id
}


# Resource: Private Service Connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = data.terraform_remote_state.gke.outputs.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
  deletion_policy = "ABANDON" # After terraform destroy, destroy it manually
}
```
### Step-02-07: c4-01-cloudsql.tf
```hcl
# Random DB Name suffix
resource "random_id" "db_name_suffix" {
  byte_length = 4
}
# Resource: Cloud SQL Database Instance
resource "google_sql_database_instance" "mydbinstance" {
  # Create DB only after Private VPC connection is created
  depends_on = [ google_service_networking_connection.private_vpc_connection ]
  name = "${local.name}-mysql-${random_id.db_name_suffix.hex}"
  database_version = var.cloudsql_database_version
  project = var.gcp_project
  deletion_protection = false
  settings {
    tier    = "db-f1-micro"
    edition = "ENTERPRISE"      # Other option is "ENTERPRISE_PLUS"
    availability_type = "ZONAL" # FOR HA use "REGIONAL"
    disk_autoresize = true
    disk_autoresize_limit = 20
    disk_size = 10
    disk_type = "PD_SSD"
    backup_configuration {
      enabled = true
      binary_log_enabled = true
    }
    ip_configuration {
      ipv4_enabled = false
      private_network = data.terraform_remote_state.gke.outputs.vpc_self_link
    }
  }
}

# Resource: Cloud SQL Database Schema
resource "google_sql_database" "mydbschema" {
  name     = "webappdb"
  instance = google_sql_database_instance.mydbinstance.name
}

# Resource: Cloud SQL Database User
resource "google_sql_user" "users" {
  name     = "umsadmin"
  instance = google_sql_database_instance.mydbinstance.name
  host     = "%"
  password = "dbpassword11"
}
```

### Step-02-08: c4-02-cloudsql-outputs.tf
```hcl
output "cloudsql_db_private_ip" {
  value = google_sql_database_instance.mydbinstance.private_ip_address
}

output "mydb_schema" {
  value = google_sql_database.mydbschema.name
}

output "mydb_user" {
  value = google_sql_user.users.name
}

output "mydb_password" {
  value = google_sql_user.users.password
  sensitive = true
}
``` 
### Step-02-09: mysql-client-install.sh
```sh
#! /bin/bash
# Update package list
sudo apt update

# Install telnet (For Troubelshooting)
sudo apt install -y telnet

# Install MySQL Client (For Troubelshooting)
sudo apt install -y default-mysql-client
```
### Step-02-10: c5-vminstance.tf
```hcl
# Firewall Rule: SSH
resource "google_compute_firewall" "fw_ssh" {
  name = "fwrule-allow-ssh22"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = data.terraform_remote_state.gke.outputs.vpc_id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-tag"]
}

# Resource Block: Create a single Compute Engine instance
resource "google_compute_instance" "myapp1" {
  name         = "mysq-client"
  machine_type = "e2-micro"
  zone         = "us-central1-a"
  tags        = [tolist(google_compute_firewall.fw_ssh.target_tags)[0]]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  # Install Webserver
  metadata_startup_script = file("${path.module}/mysql-client-install.sh")
  network_interface {
    subnetwork = data.terraform_remote_state.gke.outputs.mysubnet_id
    access_config {
      # Include this section to give the VM an external IP address
    }
  }
}

output "vm_public_ip" {
  value = google_compute_instance.myapp1.network_interface.0.access_config.0.nat_ip
}
``` 
### Step-02-11:  Execute Terraform Commands
```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply
```
### Step-02-12: Verify Cloud SQL Database
- Goto Cloud SQL -> hr-dev-mysql -> Cloud SQL Studio
- **Database:** webappdb
- **User:** umsadmin
- **Password:** dbpassword11
- Review the Cloud SQL Studio

### Step-02-13: Connect to MySQL DB from VM Instance
```sql
## SSH TO VM
SSH to VM using Cloud Shell

# MySQL Commands
mysql -h <DB-PRIVATE-IP> -u umsadmin -pdbpassword11
mysql -h 10.40.0.6 -u umsadmin -pdbpassword11
mysql> show schemas;
```

## Step-03: PROJECT-3: p3-k8sresources-terraform-manifests
### Step-03-01: c1-versions.tf
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.38.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.31"
    }      
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/ums-webapp-demo1"    
  }  
}
```
### Step-03-02: c2-01-variables.tf
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
```
### Step-03-03: terraform.tfvars
```hcl
gcp_project     = "gcplearn9"
gcp_region1     = "us-central1"
environment     = "dev"
business_divsion = "hr"
```
### Step-03-04: c2-02-local-values.tf
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
### Step-03-05: c3-01-remote-state-datasource.tf
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
```
### Step-03-06: c3-02-providers.tf
```hcl
# Provider: google
provider "google" {
  project = var.gcp_project
  region = var.gcp_region1
}

# GKE Datasource: GKE Cluster details
data "google_container_cluster" "gke" {
  name     = data.terraform_remote_state.gke.outputs.gke_cluster_name
  location = data.terraform_remote_state.gke.outputs.gke_cluster_location
}

output "gke_cluster_details" {
  value = {
    gke_endpoint = data.google_container_cluster.gke.endpoint
    gke_cluster_ca_certificate = data.google_container_cluster.gke.master_auth.0.cluster_ca_certificate
  }
}

# Resource: Access the configuration of the Google Cloud provider.
data "google_client_config" "default" {}

# Provider: Kubernetes
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.gke.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
    # Additional Reference: https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_gke_with_terraform#using-the-kubernetes-and-helm-providers
  }  
}
```
### Step-03-07: c4-06-UserMgmtWebApp-deployment.tf
```hcl
# Resource: UserMgmt WebApp Kubernetes Deployment
resource "kubernetes_deployment_v1" "usermgmt_webapp" {
  metadata {
    name = "usermgmt-webapp"
    labels = {
      app = "usermgmt-webapp"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "usermgmt-webapp"
      }
    }
    template {
      metadata {
        labels = {
          app = "usermgmt-webapp"
        }
      }
      spec {
        container {
          image = "ghcr.io/stacksimplify/kube-usermgmt-webapp:1.0.0-MySQLDB"
          name  = "usermgmt-webapp"
          #image_pull_policy = "always"  # Defaults to Always so we can comment this
          port {
            container_port = 8080
          }
          env {
            name = "DB_HOSTNAME"
            value = data.terraform_remote_state.cloudsql.outputs.cloudsql_db_private_ip
          }
          env {
            name = "DB_PORT"
            value = "3306"
          }
          env {
            name = "DB_NAME"
            value = data.terraform_remote_state.cloudsql.outputs.mydb_schema
          }
          env {
            name = "DB_USERNAME"
            value = data.terraform_remote_state.cloudsql.outputs.mydb_user
          }
          env {
            name = "DB_PASSWORD"
            value = data.terraform_remote_state.cloudsql.outputs.mydb_password
          }          
        }
      }
    }
  }
}

```
### Step-03-08: c4-07-UserMgmtWebApp-loadbalancer-service.tf
```hcl
# Resource: Kubernetes Service Manifest (Type: Load Balancer - Classic)
resource "kubernetes_service_v1" "lb_service" {
  metadata {
    name = "usermgmt-webapp-lb-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.usermgmt_webapp.spec.0.selector.0.match_labels.app
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "LoadBalancer"
  }
}

# Terraform Outputs
output "ums_loadbalancer_ip" {
  value = kubernetes_service_v1.lb_service.status[0].load_balancer[0].ingress[0].ip
}
```
### Step-03-09: Execute Terraform Commands
```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply
```
### Step-03-10: Verify Kubernetes Resources created
```t
# Verify Deployments
kubectl get deploy
Observation:
1. We should see UMS WebApp deployment in default namespace
- usermgmt-webapp

# Verify Pods
kubectl get pods
Observation:
1. You should see UMS Pod running

# Describe pod and review events
kubectl describe pod <POD-NAME>
kubectl describe pod usermgmt-webapp-cfd4c7-fnf9s

# Review UserMgmt Pod Logs
kubectl logs -f usermgmt-webapp-cfd4c7-fnf9s
Observation:
1. Review the logs and ensure it is successfully connected to MySQL Database

# Verify Services
kubectl get svc
```

### Step-03-11: Connect to CloudSQL MySQL Database 
- Goto Cloud SQL -> hr-dev-mysql -> Cloud SQL Studio
- **Database:** webappdb
- **User:** umsadmin
- **Password:** dbpassword11
- Review the Cloud SQL Studio
```t
# MySQL Query
select * from user;
Observation:
1. If UserMgmt WebApp container successfully started, it will connect to Database and create the default user named admin101
Username: admin101
Password: password101
```

### Step-03-12: Access Sample Application
```t
# Verify Services
kubectl get svc

# Access using browser
http://<LOAD-BALANCER-IP>
Username: admin101
Password: password101

# Create Users and Verify using UserMgmt WebApp in browser
admin102/password102
admin103/password103

# Verify the same in Cloud SQL MySQL DB
# MySQL Query from Cloud SQL Studio
select * from user;
Observation:
1. New users created should be present in Database


## Verify Workloads in GKE console
Go to GKE -> Workloads Tab
1. Verify Deployments
2. Verify Pods
3. Verify Services
```

## Step-04: Clean-Up P3: UserMgmt WebApp Kubernetes Resources
```t
# Project P3: p3-k8sresources-terraform-manifests
# Change Directory
cd p3-k8sresources-terraform-manifests

# Delete Kubernetes  Resources using Terraform
terraform apply -destroy -auto-approve

# Delete Provider Plugins
rm -rf .terraform*

# Verify Kubernetes Resources
kubectl get pods
kubectl get svc
Observation: 
1. All UserMgmt Web App related Kubernetes resources should be deleted
``` 
## Step-05: Clean-Up P2: Cloud SQL Private Database
```t
# Project P2: p2-cloudsql-privatedb
# Change Directory
cd p2-cloudsql-privatedb

# Delete Kubernetes  Resources using Terraform
terraform apply -destroy -auto-approve

# Delete Provider Plugins
rm -rf .terraform*

# Delete VPC Peering Connection manually
1. Delete manually because we have put setting deletion_policy = "ABANDON" # After terraform destroy, destroy it manually
2. Go to VPC Networks -> VPC Network peering -> servicenetworking-googleapis-com (hr-dev-vpc) -> DELETE
```

## Step-06: DONT DELETE P1 
```t
# Project P1: p1-gke-autopilot-cluster-private
1. Dont delete GKE cluster, we will use it in next demo
```
