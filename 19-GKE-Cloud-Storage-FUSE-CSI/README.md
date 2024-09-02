---
title: GKE Storage with Cloud Storage Buckets - GCS Fuse CSI Driver
description: Mount GCP Cloud Storage buckets to GKE Workloads
---

## Step-01: Introduction
1. **Approach-1:** Using Kubernetes YAML Manifests
2. **Approach-2:** Using Terraform Manifests

## Step-02: **Approach-1:** Using Kubernetes YAML Manifests
### Step-02-00: Verify if Cloud Storage Fuse CSI driver	enabled in GKE Cluster
- Go to GKE Cluster -> Features and verify if **Cloud Storage Fuse CSI driver** enabled

### Step-02-01: Create Cloud Storage Bucket
- Go to Cloud Storage -> Create Bucket with default settings
- **Bucket Name:** gke-object-storage-101

### Step-02-02: Service Account using Workload Identity Federation
- [Configure access to Cloud Storage buckets using GKE Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#authentication)
```t
# Get credentials for your cluster:
gcloud container clusters get-credentials CLUSTER_NAME \
    --location=LOCATION
gcloud container clusters get-credentials hr-dev-gke-cluster-autopilot \
    --location=us-central1

# Get GCP Project Number
gcloud projects describe my-sample-project --format="get(projectNumber)"
gcloud projects describe gcplearn9 --format="get(projectNumber)"

# Get GCP Project ID
gcloud projects list

# Grant one of the IAM roles for Cloud Storage to the Kubernetes ServiceAccount
gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
    --member "principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/NAMESPACE/sa/KSA_NAME" \
    --role "ROLE_NAME"

gcloud storage buckets add-iam-policy-binding gs://gke-object-storage-102 \
    --member "principal://iam.googleapis.com/projects/899156651629/locations/global/workloadIdentityPools/gcplearn9.svc.id.goog/subject/ns/mydemo1ns/sa/mydemo1sa" \
    --role "roles/storage.objectUser"

[OR]    

gcloud projects add-iam-policy-binding GCS_PROJECT \
    --member "principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/NAMESPACE/sa/KSA_NAME" \
    --role "ROLE_NAME"

gcloud projects add-iam-policy-binding gcplearn9 \
    --member "principal://iam.googleapis.com/projects/899156651629/locations/global/workloadIdentityPools/gcplearn9.svc.id.goog/subject/ns/mydemo1ns/sa/mydemo1sa" \
    --role "roles/storage.objectUser"    
```

### Step-02-03: c1-k8s-namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mydemo1ns
```
### Step-02-04: c2-k8s-serviceaccount.yaml
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mydemo1sa
  namespace: mydemo1ns
```
### Step-02-05: c3-k8s-pv.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gcs-fuse-csi-pv
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 5Gi
  storageClassName: dummy-storage-class
  mountOptions:
    - implicit-dirs
  csi:
    driver: gcsfuse.csi.storage.gke.io
    volumeHandle: gke-object-storage-101
    volumeAttributes:
      gcsfuseLoggingSeverity: warning
```
### Step-02-06: c4-k8s-pvc.yaml
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gcs-fuse-csi-static-pvc
  namespace: mydemo1ns
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  volumeName: gcs-fuse-csi-pv
  storageClassName: dummy-storage-class
```
### Step-02-08: c5-kubernetes-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment  
metadata: 
  name: myapp1-deployment
  namespace: mydemo1ns
spec: 
  replicas: 2
  selector: 
    matchLabels: 
      app: myapp1
  template:
    metadata: 
      labels:
        app: myapp1 
      annotations: 
        gke-gcsfuse/volumes: "true"        
    spec:
      serviceAccountName: mydemo1sa    
      containers: 
        - name: myapp1-container
          image: ghcr.io/stacksimplify/kubenginx:1.0.0
          ports: 
            - containerPort: 80          
          volumeMounts:
          - name: gcs-fuse-csi-static
            mountPath: /usr/share/nginx/html
            readOnly: true      
      volumes:
      - name: gcs-fuse-csi-static
        persistentVolumeClaim:
          claimName: gcs-fuse-csi-static-pvc                   
```
### Step-02-09 c6-kubernetes-loadbalancer-service.yaml
```yaml
apiVersion: v1
kind: Service 
metadata:
  name: myapp1-lb-service
  namespace: mydemo1ns 
spec:
  type: LoadBalancer # ClusterIp, # NodePort
  selector:
    app: myapp1
  ports: 
    - name: http
      port: 80 # Service Port
      targetPort: 80 # Container Port
```
### Step-02-10: Deploy Kubernetes YAML Manifests and Verify
```t
# Deploy Kubernetes Manifests
kubectl apply -f p2-k8sresources-yaml

# List Kubernetes PV
kubectl get pv

# List Kubernetes PVC
kubectl get pv -n mydemo1ns

# List Kubernetes Deployment
kubectl get deploy -n mydemo1ns

# List Kubernetes Pods
kubectl get pods -n mydemo1ns

# Describe Pod and review containers in a pod (Review Init Container: gke-gcsfuse-sidecar)
kubectl describe pod <POD-NAME> -n mydemo1ns
Observation:
1. Review Initi Container which is related to gke-gcsfuse-sidecar

# Upload files from "static-files" folder to cloud storage bucket
Cloud Storage Bucket: gke-object-storage-101
Files: index.html, file1.html, file2.html

# List Kubernetes Services
kubectl get svc -n mydemo1ns

# Access Application
http://35.239.28.66 
http://35.239.28.66/file1.html
http://35.239.28.66/file2.html

# Clean-Up Kubernetes Resources
kubectl delete -f p2-k8sresources-yaml

# Delete content in Cloud Storage Bucket and Cloud Storage Bucket
gcloud storage rm -r gs://gke-object-storage-101
```

## Step-03: **Approach-2:** Using Terraform Manifests
1. Create Cloud Storage Bucket
2. Create Cloud Storage Bucket IAM Binding
3. Create k8s Persistent Volume
4. Create k8s Namespace
5. Create k8s Persistent Volume Claim
6. Create k8s Service Account
7. Create k8s Deployment
8. Create k8s Load Balancer Service

### Step-03-01: c1-versions.tf
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.39.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.31"
    }      
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gcs-fuse-storage-demo"    
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

### Step-03-03: c2-02-local-values.tf

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

### Step-03-04: c3-01-remote-state-datasource.tf

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

### Step-03-05: c3-02-providers.tf

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


### Step-03-06: c4-01-cloud-storage-bucket.tf
```hcl
# Random suffix
resource "random_id" "bucket_name_suffix" {
  byte_length = 4
}

# Resource: Cloud Storage Bucket
resource "google_storage_bucket" "my_bucket" {
  name     = "${local.name}-gcs-fuse-${random_id.bucket_name_suffix.hex}"
  location = "US"  # Setting this to "US" makes it a multi-regional bucket
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  force_destroy = true 
}

# Outputs
output "my_bucket" {
  value = google_storage_bucket.my_bucket.name
}
```

### Step-03-07: c4-02-bucket-iam-binding.tf
```hcl
# Datasource: Get Project Information
data "google_project" "project" {
}

# Outputs
output "project_number" {
  value = data.google_project.project.number
}

# Resource: Cloud Storage Bucket IAM Binding
resource "google_storage_bucket_iam_binding" "iam_binding" {
  bucket = google_storage_bucket.my_bucket.name
  role   = "roles/storage.objectUser"
  members = [
    "principal://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.gcp_project}.svc.id.goog/subject/ns/${kubernetes_namespace.myns.metadata[0].name}/sa/${kubernetes_service_account.mysa.metadata[0].name}"
  ]
}
```


### Step-03-08: c5-01-persistent-volume.tf
```hcl
# Resource: Kubernetes Persistent Volume
resource "kubernetes_persistent_volume" "gcs_fuse_csi_pv" {
  metadata {
    name = "${local.name}-gcs-fuse-csi-pv"
  }
  spec {
    storage_class_name = "dummy-storage-class"
    access_modes       = ["ReadWriteMany"]
    mount_options = ["implicit-dirs"]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_source {
      csi {
        driver       = "gcsfuse.csi.storage.gke.io"
        volume_handle = google_storage_bucket.my_bucket.name
        volume_attributes = {
          gcsfuseLoggingSeverity = "warning"
        }
      }
    }
  }
}

# Outputs
output "my_pv" {
  value = kubernetes_persistent_volume.gcs_fuse_csi_pv.metadata[0].name
}
```

### Step-03-09: c5-02-namespace.tf
```hcl
# Resource: Kubernetes Namespace
resource "kubernetes_namespace" "myns" {
  metadata {
    name = "${local.name}-mydemo-ns"
  }
}

# Outputs
output "my_namespace" {
  value = kubernetes_namespace.myns.metadata[0].name 
}
```

## Step-03-10: c5-03-persistent-volume-claim.tf

```hcl
# Resource: Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "gcs_fuse_csi_static_pvc" {
  metadata {
    name      = "${local.name}-gcs-fuse-csi-static-pvc"
    namespace = kubernetes_namespace.myns.metadata[0].name 
  }
  spec {
    access_modes = ["ReadWriteMany"]
    volume_name       = kubernetes_persistent_volume.gcs_fuse_csi_pv.metadata[0].name
    storage_class_name = "dummy-storage-class"
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

# Outputs
output "my_pvc" {
  value =  kubernetes_persistent_volume_claim.gcs_fuse_csi_static_pvc.metadata[0].name
}

```

### Step-03-11: c5-04-service-account.tf

```hcl
# Resource: Kubernetes Service Account
resource "kubernetes_service_account" "mysa" {
  metadata {
    name      = "${local.name}-mydemosa"
    namespace = kubernetes_namespace.myns.metadata[0].name
  }
}

# Outputs
output "my_serviceaccount" {
  value = kubernetes_service_account.mysa.metadata[0].name 
}
```



## Step-03-12: c5-05-myapp1-deployment.tf

```hcl
# Resource: Kubernetes Deployment
resource "kubernetes_deployment_v1" "myapp1_deployment" {
  metadata {
    name      = "${local.name}-myapp1-deployment"
    namespace = kubernetes_namespace.myns.metadata[0].name 
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
        annotations = {
          "gke-gcsfuse/volumes" = "true"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.mysa.metadata[0].name 
        container {
          name  = "myapp1-container"
          image = "ghcr.io/stacksimplify/kubenginx:1.0.0"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "gcs-fuse-csi-static"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }
        }
        volume {
          name = "gcs-fuse-csi-static"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.gcs_fuse_csi_static_pvc.metadata[0].name
          }
        }
      }
    }
  }
}
```



### Step-03-13: c5-06-myapp1-loadbalancer-service.tf

```hcl
# Resource: Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "myapp1_lb_service" {
  metadata {
    name      = "${local.name}-myapp1-lb-service"
    namespace = kubernetes_namespace.myns.metadata[0].name 
  }
  spec {
    type = "LoadBalancer"
    selector = {
      app = kubernetes_deployment_v1.myapp1_deployment.spec[0].selector[0].match_labels.app
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }
}

# Terraform Outputs
output "myapp1_loadbalancer_ip" {
  value = kubernetes_service_v1.myapp1_lb_service.status[0].load_balancer[0].ingress[0].ip
}
```


### Step-03-14: terraform.tfvars
```hcl
gcp_project     = "gcplearn9"
gcp_region1     = "us-central1"
environment     = "dev"
business_divsion = "hr"
```

### Step-03-15: Execute Terraform Commands
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

### Step-03-16: Verify resources
```t
# List Kubernetes PV
kubectl get pv

# List Kubernetes PVC
kubectl get pv -n mydemo1ns

# List Kubernetes Deployment
kubectl get deploy -n mydemo1ns

# List Kubernetes Pods
kubectl get pods -n mydemo1ns

# Describe Pod and review containers in a pod (Review Init Container: gke-gcsfuse-sidecar)
kubectl describe pod <POD-NAME> -n mydemo1ns
Observation:
1. Review Initi Container which is related to gke-gcsfuse-sidecar

# Upload files from "static-files" folder to cloud storage bucket
Cloud Storage Bucket: hr-dev-gcs-fuse-XXXXX
Files: index.html, file1.html, file2.html

# List Kubernetes Services
kubectl get svc -n mydemo1ns

# Access Application
http://35.239.28.66 
http://35.239.28.66/file1.html
http://35.239.28.66/file2.html
```
### Step-03-17: Clean Up Resources
```t
# Change Directory
cd p3-k8sresources-terraform-manifests

# Terraform Destroy
terraform apply -destroy -auto-approve
```
