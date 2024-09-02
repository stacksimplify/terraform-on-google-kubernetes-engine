---
title: GCP Google Kubernetes Engine - GKE Storage
description: Deploy UserMgmt WebApp on GKE with MySQL as Database using Terraform
---

## Step-01: Introduction
- Create Terraform configs for following Kubernetes Resources
  - Kubernetes Storage Class
  - Kubernetes Persistent Volume Claim
  - Kubernetes Config Map
  - Kubernetes Deployment for MySQL DB
  - Kubernetes ClusterIP Service for MySQL DB
  - Kubernetes Deployment for User Management Web Application
  - Kubernetes Load Balancer for UMS Web App

## Pre-requisite: Verify Compute Engine persistent disk CSI Driver enabled
- Go to GKE cluster -> DETAILS -> FEATURES -> **Compute Engine persistent disk CSI Driver** should be enabled

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
## Step-02: c2-01-variables.tf
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
## Step-03: c2-02-local-values.tf
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
## Step-04: c3-01-remote-state-datasource.tf
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
## Step-05: c3-02-providers.tf
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
## Step-06: c4-01-storage-class.tf
```hcl
# Resource: Kubernetes Storage Class
resource "kubernetes_storage_class_v1" "gke_sc" {  
  metadata {
    name = "gke-pd-standard-rwo-sc"
  }
  storage_provisioner = "pd.csi.storage.gke.io"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy = "Retain"
  parameters = {
    type = "pd-standard" # Other Options supported are pd-ssd, pd-standard
  }
}

```
## Step-07: c4-02-persistent-volume-claim.tf
```hcl
# Resource: Persistent Volume Claim
resource "kubernetes_persistent_volume_claim_v1" "pvc" {
  metadata {
    name = "gke-pd-mysql-pv-claim"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class_v1.gke_sc.metadata.0.name 
    resources {
      requests = {
        storage = "4Gi"
      }
    }
  }
}
```
## Step-08: webappdb.sql
```sql
DROP DATABASE IF EXISTS webappdb;
CREATE DATABASE webappdb; 
```
## Step-09: c4-03-UserMgmtWebApp-ConfigMap.tf
```hcl
 # Resource: Config Map
 resource "kubernetes_config_map_v1" "config_map" {
   metadata {
     name = "usermanagement-dbcreation-script"
   }
   data = {
    "webappdb.sql" = "${file("${path.module}/webappdb.sql")}"
   }
 } 
```
## Step-10: c4-04-mysql-deployment.tf
```hcl
# Resource: MySQL Kubernetes Deployment
resource "kubernetes_deployment_v1" "mysql_deployment" {
  metadata {
    name = "mysql"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mysql"
      }          
    }
    strategy {
      type = "Recreate"
    }  
    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }
      spec {
        volume {
          name = "mysql-persistent-storage"
          persistent_volume_claim {
            #claim_name = kubernetes_persistent_volume_claim_v1.pvc.metadata.0.name # THIS IS NOT GOING WORK, WE NEED TO GIVE PVC NAME DIRECTLY OR VIA VARIABLE, direct resource name reference will fail.
            claim_name = "gke-pd-mysql-pv-claim"
          }
        }
        volume {
          name = "usermanagement-dbcreation-script"
          config_map {
            name = kubernetes_config_map_v1.config_map.metadata.0.name 
          }
        }
        container {
          name = "mysql"
          image = "mysql:8.0"
          port {
            container_port = 3306
            name = "mysql"
          }
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value = "dbpassword11"
          }
          volume_mount {
            name = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }
          volume_mount {
            name = "usermanagement-dbcreation-script"
            mount_path = "/docker-entrypoint-initdb.d" #https://hub.docker.com/_/mysql Refer Initializing a fresh instance                                            
          }
        }
      }
    }      
  }
}
```
## Step-11: c4-05-mysql-clusterip-service.tf
```hcl
# Resource: MySQL Cluster IP Service
resource "kubernetes_service_v1" "mysql_clusterip_service" {
  metadata {
    name = "mysql"
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.mysql_deployment.spec.0.selector.0.match_labels.app 
    }
    port {
      port        = 3306 # Service Port
      #target_port = 3306 # Container Port  # Ignored when we use cluster_ip = "None"
    }
    type = "ClusterIP"
    cluster_ip = "None" # This means we are going to use Pod IP   
  }
}
```
## Step-12: c4-06-UserMgmtWebApp-deployment.tf
```hcl
# Resource: UserMgmt WebApp Kubernetes Deployment
resource "kubernetes_deployment_v1" "usermgmt_webapp" {
  depends_on = [kubernetes_deployment_v1.mysql_deployment]
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
        init_container {
          name  = "init-db"
          image = "busybox:1.31"
          command = ["sh", "-c", "echo -e \"Checking for the availability of MySQL Server deployment\"; while ! nc -z mysql 3306; do sleep 1; printf \"-\"; done; echo -e \"  >> MySQL DB Server has started\";"]
        }        
        container {
          image = "ghcr.io/stacksimplify/kube-usermgmt-webapp:1.0.0-MySQLDB"
          name  = "usermgmt-webapp"
          #image_pull_policy = "always"  # Defaults to Always so we can comment this
          port {
            container_port = 8080
          }
          env {
            name = "DB_HOSTNAME"
            #value = "mysql"
            value = kubernetes_service_v1.mysql_clusterip_service.metadata.0.name 
          }
          env {
            name = "DB_PORT"
            #value = "3306"
            value = kubernetes_service_v1.mysql_clusterip_service.spec.0.port.0.port
          }
          env {
            name = "DB_NAME"
            value = "webappdb"
          }
          env {
            name = "DB_USERNAME"
            value = "root"
          }
          env {
            name = "DB_PASSWORD"
            #value = "dbpassword11"
            value = kubernetes_deployment_v1.mysql_deployment.spec.0.template.0.spec.0.container.0.env.0.value
          }          
        }
      }
    }
  }
}


```
## Step-13: c4-07-UserMgmtWebApp-loadbalancer-service.tf
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
## Step-14: terraform.tfvars
```hcl
gcp_project     = "gcplearn9"
gcp_region1     = "us-central1"
environment     = "dev"
business_divsion = "hr"
```

## Step-15: Deploy Sample App: Execute Terraform Commands
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
```

## Step-16: Verify Kubernetes Resources created
```t
# Verify Storage Class
kubectl get storageclass
kubectl get sc
Observation:
1. You should find the custom GKE storage class created in addition to default ones
  
# Verify PVC and PV
kubectl get pvc
kubectl get pv
Observation:
1. Status should be in BOUND state

# Verify Deployments
kubectl get deploy
Observation:
1. We should see both deployments in default namespace
- mysql
- usermgmt-webapp

# Verify Pods
kubectl get pods
Observation:
1. You should see both pods running

# Describe both pods and review events
kubectl describe pod <POD-NAME>
kubectl describe pod mysql-6fdd448876-hdhnm
kubectl describe pod usermgmt-webapp-cfd4c7-fnf9s

# Review UserMgmt Pod Logs
kubectl logs -f usermgmt-webapp-cfd4c7-fnf9s
Observation:
1. Review the logs and ensure it is successfully connected to MySQL POD

# Verify Services
kubectl get svc
```

## Step-17: Connect to MySQL Database Pod
```t
# Connect to MySQL Database 
kubectl run -it --rm --image=mysql:8.0 --restart=Never mysql-client -- mysql -h mysql -pdbpassword11

# Verify usermgmt schema got created which we provided in ConfigMap
mysql> show schemas;
mysql> use webappdb;
mysql> show tables;
mysql> select * from user;

Observation:
1. If UserMgmt WebApp container successfully started, it will connect to Database and create the default user named admin101
Username: admin101
Password: password101
```
## Step-18: Access Sample Application
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

# Verify the same in MySQL DB
## Connect to MySQL Database 
kubectl run -it --rm --image=mysql:8.0 --restart=Never mysql-client -- mysql -h mysql -pdbpassword11

## Verify usermgmt schema got created which we provided in ConfigMap
mysql> show schemas;
mysql> use webappdb;
mysql> show tables;
mysql> select * from user;

## Verify Workloads in GKE console
Go to GKE -> Workloads Tab
1. Verify Deployments
2. Verify Pods
3. Verify Services

## Verify Compute Engine Persistent Disks
Go to Compute Engine -> Disks
1. Verify the persistent disk created for MySQL Deployment
```

## Step-19: Clean-Up - UserMgmt WebApp Kubernetes Resources
```t
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

# Verify and Delete Persistent Disks
Go to Compute Engine -> Storage Disks 
1. Delete the persistent disk created for this demo
``` 

## Step-20: DONT DELETE P1 Project
```t
# Project P1: p1-gke-autopilot-cluster-private
1. Dont delete GKE cluster, we will use it in next demo
```
