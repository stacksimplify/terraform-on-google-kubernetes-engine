---
title: GKE with Kubernetes Gateway API - Load Balancer with Cloud DNS and Cloud Domains
description: Create GCP Application Load Balancer using GKE Kubernetes Gateway API with Cloud DNS and Cloud Domains
---

## Step-01: Introduction
1. Create 
  - GCP Application Load Balancer using Kubernetes Gateway API
  - Static IP for Load Balancer 
  - Production grade SSL with Google Cloud Certificate Manager 
  - Cloud DNS 
    - DNS Authorization for generating production grade ssl
    - DNS register the load balancer IP
  - Cloud Domains
    - Registered domain in Cloud Domains
2. All the above will created using Terraform Manifests

## Step-02: Project-2: p2-regional-k8sresources-terraform-manifests: Terraform Manifests
### Step-02-01: NO changes to following manifests
- **Folder:** p2-k8sresources-terraform-manifests
- c2-01-variables.tf
- c2-02-local-values.tf
- c3-01-remote-state-datasource.tf
- c3-02-providers.tf
- c4-01-myapp1-deployment.tf
- c4-02-myapp1-clusterip-service.tf
- c4-03-myapp1-healthcheck.tf
- c4-04-myapp1-session-affinity.tf
- c5-01-gateway.tf
- c5-02-gateway-http-to-https-route.tf
- c5-03-gateway-http-route.tf
- c6-static-ip.tf
- c7-certificate-manager.tf
- terraform.tfvars


### Step-02-02: c1-versions.tf
- Update your Cloud Storage Bucket
```t
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-gateway-regional-demo1"    
  }  
```

### Step-02-03: c8-cloud-dns.tf
```hcl
# Locals Block
## 1. You should have a registered Domain
## 2. Your registered domain is configured in Cloud DNS for DNS management
locals {
  mydomain = "mygkeapp101.kalyanreddydaida.com"
  dns_managed_zone = "kalyanreddydaida-com"
}

# Resource: Cloud DNS Record Set for A Record
resource "google_dns_record_set" "a_record" {
  project      = "kdaida123"
  managed_zone = "${local.dns_managed_zone}"
  name         = "${local.mydomain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.static_ip.address]
}
```

### Step-02-04: c7-certificate-manager.tf
```hcl
# Resource: Certificate Manager DNS Authorization
resource "google_certificate_manager_dns_authorization" "myapp1" {
  location    = var.gcp_region1
  name        = "${local.name}-myapp1-dns-authorization"
  description = "myapp1 dns authorization"
  domain      = "${local.mydomain}"
}

# Resource: Certificate manager certificate
resource "google_certificate_manager_certificate" "myapp1" {
  location    = var.gcp_region1
  name        = "${local.name}-myapp1-ssl-certificate"
  description = "${local.name} Certificate Manager SSL Certificate"
  scope       = "DEFAULT"
  labels = {
    env = "dev"
  }
  managed {
    domains = [
      google_certificate_manager_dns_authorization.myapp1.domain
      ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.myapp1.id
      ]
  }
}


# Resource: DNS record to be created in DNS zone for DNS Authorization
resource "google_dns_record_set" "myapp1_cname" {
  project      = "kdaida123"
  managed_zone = "${local.dns_managed_zone}"
  name         = google_certificate_manager_dns_authorization.myapp1.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.myapp1.dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.myapp1.dns_resource_record[0].data]
}
```

### Step-02-05: Execute Terraform Commands
```t
# Change Directory
cd p2-regional-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

### Step-02-06: Verify Kubernetes Resources
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

# Verify Certificate Manager SSL Certificate
Go to Cloud Certificate Manager
Observation:
1. It will take 5 to 10 minutes to get the production certificate get approved


# Access Application
http://<DNS-URL> 
Observation:
1. Should redirect to HTTPS url
2. No HTTPS warning as it is a prod grade certificate
```

### Step-02-07: Clean-Up
```t
# Change Directory
cd p2-regional-k8sresources-terraform-manifests

# Terraform Destroy
terraform apply -destroy -auto-approve
```

## Gateway Documentation
- https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.Listener




