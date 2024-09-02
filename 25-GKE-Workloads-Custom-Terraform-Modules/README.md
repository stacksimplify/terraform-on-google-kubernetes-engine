---
title: GCP Google Cloud Platform - Create GKE Kubernetes Deployment Custom Terraform Module
description: Learn to implement GKE Kubernetes Deployment Custom Terraform Module
---

## Step-01: Introduction
- Create a GKE Kubernetes Deployment custom Terraform Module (modules/kubernetes_deployment)
- Call the custom module in project-2

## Step-02: Create Custom Module for Kubernetes Deployment
- **Folder Path:** modules/kubernetes_deployment
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
variable "deployment_name" {
  type        = string
  description = "(Required) Kubernetes Deployment Name"
}

variable "namespace" {
  type        = string
  description = "(Optional) Kubernetes Deployment Name"
  default     = "default"
}

variable "replicas" {
  type        = number 
  description = "(Required) Number of Replicas"
}

variable "app_name_label" {
  type        = string
  description = "(Required) App Name label"
}
```
### Step-02-03: main.tf
```hcl
# Resource: Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp1" {
  metadata {
    name = var.deployment_name
    namespace = var.namespace
    labels = {
      app = var.app_name_label
    }
  } 
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = var.app_name_label
      }
    }
    template {
      metadata {
        labels = {
          app = var.app_name_label
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
### Step-02-04: outputs.tf
```hcl
# Terraform Outputs
output "deployment_labels" {
  description = "Kubernetes Deployment Selector Match Labels"
  value = kubernetes_deployment_v1.myapp1.spec[0].selector[0].match_labels.app
}
```

## Step-03: Call the Custom Kubernetes Deployment Terraform Module
- **Folder Path:** p2-k8sresources-terraform-manifests
### Step-03-01: NO CHANGES
1. c1-versions.tf: REVIEW Cloud storage bucket
2. c2-01-variables.tf
3. c2-02-local-values.tf
4. c3-01-remote-state-datasource.tf
5. c3-02-providers.tf: REVIEW Cloud storage bucket
6. terraform.tfvars
### Step-03-02: c4-kubernetes-deployment.tf
```hcl
# Module: Kubernetes Deployment Manifest
module "myapp1_deployment" {
  source = "../modules/kubernetes_deployment"
  deployment_name = "${local.name}-myapp1"
  app_name_label = "${local.name}-myapp1"
  replicas = 2
}

# Outputs
output "deployment_labels" {
  value = module.myapp1_deployment.deployment_labels
}
```
### Step-03-03: c5-kubernetes-loadbalancer-service.tf
- Update `spec.selector`
```hcl
# Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "lb_service" {
  metadata {
    name = "${local.name}-myapp1-lb-service"
  }
  spec {
    selector = {
      app = module.myapp1_deployment.deployment_labels
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
### Step-03-04: Execute Terraform Commands to Deploy in Dev GKE Cluster and Verify
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
### Step-03-05: Execute Terraform Commands to Deploy Kubernetes Resources and Verify
```t
## Deploy Kubernetes Resources in GKE Cluster
Project-2: p2-k8sresources-terraform-manifests

# Change Directory
cd p2-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify Kubernetes Deployments
kubectl get deploy

# Verify Kubernetes Pods
kubectl get pods

# Verify Kubernetes Services
kubectl get svc

# Access Application
http://<LB-IP>
```
### Step-03-06: Clean-Up
```t
## Delete Kubernetes Resources
# Change Directory
cd p2-k8sresources-terraform-manifests

# Delete Kubernetes Resources
terraform apply -destroy -auto-approve
```
