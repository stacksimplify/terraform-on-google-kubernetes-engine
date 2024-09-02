---
title: GKE with Kubernetes Gateway API - Load Balancer with Static IP
description: Create GCP Application Load Balancer using GKE Kubernetes Gateway API and Regional Static IP for LB
---

## Step-01: Introduction
1. Create GCP Application Load Balancer using Kubernetes Gateway API and Static IP for Load Balancer
2. **Approach-1:** Using Kubernetes YAML Manifests
3. **Approach-2:** Using Terraform Manifests

## Step-02: **Approach-1:** Using Kubernetes YAML Manifests
### Step-02-01: NO CHANGES from previous demo
1. 01-myapp1-deployment.yaml
2. 02-myapp1-clusterip-service.yaml
3. 04-gateway-http-route.yaml
### Step-02-02: Create Regional Static IP
```t
# Create Regional Load Balancer IP
gcloud compute addresses create my-regional-ip1 \
    --region="REGION_NAME" \
    --project=my-project-id

gcloud compute addresses create my-regional-ip1 \
    --region="us-central1" \
    --project=gcplearn9 \
    --network-tier="STANDARD"

# List IP Addresss    
gcloud compute addresses list
```

### Step-02-03: 03-gateway.yaml
```yaml
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: mygateway1-regional
spec:
  gatewayClassName: gke-l7-regional-external-managed
  listeners:
  - name: http
    protocol: HTTP
    port: 80
  addresses:
  - type: NamedAddress
    value: my-regional-ip1
```
### Step-02-04: Deploy and Verify Resources
```t
# List Kubernetes Gateway Classes
kubectl get gatewayclass

# Deploy Kubernetes Resources
kubectl apply -f p2-regional-k8sresources-yaml

# List Kubernetes Deployments
kubectl get deploy

# List Kubernetes Pods
kubectl get pods

# List Kubernetes Services
kubectl get svc

# List Kubernetes Gateways created using Gateway API
kubectl get gateway
kubectl get gtw

# Describe Gateway
kubectl describe gateway mygateway1-regional

# List HTTP Route
kubectl get httproute

# Verify Gateway is GCP GKE Console
Go to GKE Console -> Networking -> Gateways, Services & Ingress -> mygateway1-regional

# Verify GCP Cloud Load Balancer
Go to Cloud Load Balancers -> Review load balancer settings

# Access Application
http://<LB-IP>
```
### Step-02-05: Clean-up
```t
# Delete Kubernetes Resources
kubectl delete -f p2-regional-k8sresources-yaml
```

## Step-03: Project-3: p3-k8sresources-terraform-manifests: Terraform Manifests
### Step-03-01: NO changes to following manifests
- **Folder:** p3-k8sresources-terraform-manifests
- c2-01-variables.tf
- c2-02-local-values.tf
- c3-01-remote-state-datasource.tf
- c3-02-providers.tf
- c4-myapp1-deployment.tf
- c5-myapp1-clusterip-service.tf
- c7-gateway-http-route.tf
- terraform.tfvars

### Step-03-02: c1-versions.tf
- Update your Cloud Storage Bucket
```t
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-gateway-regional-demo1"    
  }  
```

### Step-03-03: c6-gateway.tf
```hcl
resource "kubernetes_manifest" "my_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name = "mygateway1-regional"
      namespace = "default"
    }
    spec = {
      gatewayClassName = "gke-l7-regional-external-managed"
      listeners = [{
        name     = "http"
        protocol = "HTTP"
        port     = 80
      }]
      addresses = [{
        type  = "NamedAddress"
        value = google_compute_address.static_ip.name
      }]        
    }
  }
}
```
### Step-03-04: c8-static-ip.tf
```hcl
resource "google_compute_address" "static_ip" {
  name   = "${local.name}-my-regional-ip"
  region = var.gcp_region1
  network_tier = "STANDARD"
}

output "static_ip_address" {
  value = google_compute_address.static_ip.address
}

output "static_ip_name" {
  value = google_compute_address.static_ip.name
}
```
### Step-03-05: Execute Terraform Commands
```t
# Change Directory
cd p3-regional-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

### Step-03-06: Verify Kubernetes Resources
```t
# List Kubernetes Deployments
kubectl get deploy

# List Kubernetes Pods
kubectl get pods

# List Kubernetes Services
kubectl get svc

# List Kubernetes Gateways created using Gateway API
kubectl get gateway
kubectl get gtw

# Describe Gateway
kubectl describe gateway mygateway1-regional

# List HTTP Route
kubectl get httproute

# Verify Gateway is GCP GKE Console
Go to GKE Console -> Networking -> Gateways, Services & Ingress -> mygateway1-regional

# Verify GCP Cloud Load Balancer
Go to Cloud Load Balancers -> Review load balancer settings

# Access Application
http://<LB-IP>
```

### Step-03-07: Clean-Up
```t
# Change Directory
cd p3-regional-k8sresources-terraform-manifests

# Terraform Destroy
terraform apply -destroy -auto-approve
```

## Gateway Documentation
- https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.Listener

