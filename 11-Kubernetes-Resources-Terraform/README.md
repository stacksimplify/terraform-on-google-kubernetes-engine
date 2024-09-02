---
title: Kubernetes Resources using Terraform 
description: Create Kubernetes Resources using Terraform Kubernetes Provider
---

## Step-01: Introduction
1. [Kubernetes Terraform Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
2. Kubernetes Resources using Terraform
   1. Kubernetes Deployment Resource
   2. Kubernetes LoadBalancer Service Resource
3. [Terraform Remote State Datasource Concept](https://www.terraform.io/docs/language/state/remote-state-data.html)
4. [Terraform Backends Concept](https://www.terraform.io/docs/language/settings/backends/index.html)

## Step-02: Review GCP Cluster Resouces
- **Folder:** `09-GKE-Public-Standard-Cluster/p1-gke-public-cluster`
- No changes 

## Step-03: c1-versions.tf
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- **Folder:** p3-k8sresources-terraform-manifests
```hcl
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
      version = ">= 2.31"
    }      
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-demo1"    
  }  
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
## Step-06: c3-01-remote-state-datasource.tf
- [Terraform Remote State Datasource](https://www.terraform.io/language/state/remote-state-data)
- **Folder:** p3-k8sresources-terraform-manifests
- **Important Note:** We will use the Terraform State file `default.tfstate` file from GCP GKE Terraform project to get the GKE Resources information present in the statefile outputs section
```hcl
# Terraform Remote State Datasource
data "terraform_remote_state" "gke" {
  backend = "gcs"
  config = {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster-public"
  }  
}

output "p1_gke_cluster_name" {
  value = data.terraform_remote_state.gke.outputs.gke_cluster_name
}

output "p1_gke_cluster_location" {
  value = data.terraform_remote_state.gke.outputs.gke_cluster_location
}
```
## Step-07: c3-02-providers.tf
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- **Folder:** p3-k8sresources-terraform-manifests
- Define GCP Provider and Kubernetes Provider
- Also define the Terraform Datasources required to access required data. 
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
## Step-08: c4-kubernetes-deployment.tf
- **Review** [Terraform Kubernetes Versioned Resource Names](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/guides/versioned-resources)
- [Terraform Kubernetes Deployment Manifest](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment_v1)
- **Folder:** p3-k8sresources-terraform-manifests
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
          }
        }
      }
    }
}
```
## Step-09: c5-kubernetes-loadbalancer-service.tf
- **Folder:** p3-k8sresources-terraform-manifests
- [Terraform Kubernetes Service Manifest](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1)
```t
# Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "lb_service" {
  metadata {
    name = "myapp1-lb-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.myapp1.spec.0.selector.0.match_labels.app
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}

# Terraform Outputs
output "myapp1_loadbalancer_ip" {
  value = kubernetes_service_v1.lb_service.status[0].load_balancer[0].ingress[0].ip
}
```
## Step-10: Create Kubernetes Resources: Execute Terraform Commands
```t
# Change Directroy
cd 11-Kubernetes-Resources-Terraform/p3-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
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
```

## Step-12: Verify Kubernetes Resources via GCP console
1. Go to Services -> GCP -> Load Balancing -> Load Balancers
2. Verify Tabs
   - Description: Make a note of LB DNS Name
   - Instances
   - Health Checks
   - Listeners
   - Monitoring

## Step-13: Clean-Up
```t
# Delete Kubernetes  Resources
cd p3-k8sresources-terraform-manifests
terraform apply -destroy -auto-approve
rm -rf .terraform* 

# Delete GCP GKE Cluster
cd 09-GKE-Public-Standard-Cluster/p1-gke-public-cluster/
terraform apply -destroy -auto-approve
rm -rf .terraform* 
```