---
title: GKE with Kubernetes Gateway API - Load Balancer HTTP to HTTPS Redirect
description: Create GCP Application Load Balancer using GKE Kubernetes Gateway API, SSL with Certificate manager, HTTP to HTTPS Redirect
---

## Step-01: Introduction
1. Create GCP Application Load Balancer using Kubernetes Gateway API, Static IP for Load Balancer, Self-signed SSL with Google Cloud Certificate Manager
2. **Approach-1:** Using Kubernetes YAML Manifests
3. **Approach-2:** Using Terraform Manifests

## Step-02: **Approach-1:** Using Kubernetes YAML Manifests
### Step-02-01: NO CHANGES from previous demo
1. 01-myapp1-deployment.yaml
2. 02-myapp1-clusterip-service.yaml

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
### Step-02-03: Create Self-signed SSL certificates
```t
# Change Directory
cd p2-regional-k8sresources-yaml/self-signed-ssl

# Create your app1 key:
openssl genrsa -out app1.key 2048

# Create your app1 certificate signing request:
openssl req -new -key app1.key -out app1.csr -subj "/CN=app1.stacksimplify.com"

# Create your app1 certificate:
openssl x509 -req -days 7300 -in app1.csr -signkey app1.key -out app1.crt
```

### Step-02-04: Create Certificate Manager Regional cert 
```t
# Create SSL Cert using Certificate Manager
gcloud certificate-manager certificates create "CERTIFICATE_NAME" \
    --certificate-file="CERTIFICATE_FILE" \
    --private-key-file="PRIVATE_KEY_FILE" \
    --location="REGION"
Important Note: If no location provided it is global certificate

# Change Directory
cd p2-regional-k8sresources-yaml/self-signed-ssl

# Create Regional Cert: us-central1
gcloud certificate-manager certificates create "app1-us-central1-cert" \
    --certificate-file="app1.crt" \
    --private-key-file="app1.key" \
    --location="us-central1"    

# Regional: List Certificates
gcloud certificate-manager certificates list --location us-central1
```

### Step-02-05: 03-gateway.yaml
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
  - name: https
    protocol: HTTPS
    port: 443  
    tls:
      mode: Terminate
      options: 
        networking.gke.io/cert-manager-certs: app1-us-central1-cert  
  addresses:
  - type: NamedAddress
    value: my-regional-ip1
```
### Step-02-06: 05-gateway-http-to-https-route.yaml
```yaml
kind: HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: redirect
spec:
  parentRefs:
  - name: mygateway1-regional
    sectionName: http
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
```

### Step-02-07: Deploy and Verify Resources
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

# Host Entry
35.208.69.211  app1.stacksimplify.com 

# Access Application
http://<DNS-URL> should redirect to https://<DNS-URL>
```
### Step-02-07: Clean-up
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
- c7-static-ip.tf
- c8-certificate-manager.tf
- terraform.tfvars


### Step-03-02: c1-versions.tf
- Update your Cloud Storage Bucket
```t
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-gateway-regional-demo1"    
  }  
```
### Step-03-03: c6-01-gateway.tf
```hcl
resource "kubernetes_manifest" "my_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name = "mygateway1-regional"
      namespace = "default"
    }
    spec = {
      gatewayClassName = "gke-l7-regional-external-managed"
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
        },     
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          tls = {
            mode = "Terminate"
            options = {
              "networking.gke.io/cert-manager-certs" = google_certificate_manager_certificate.app1_cert.name
            }
          }
        }
      ]
      addresses = [{
        type  = "NamedAddress"
        value = google_compute_address.static_ip.name
      }]        
    }
  }
}
```

### Step-03-04: c6-03-gateway-http-to-https-route.tf
```hcl
resource "kubernetes_manifest" "http_to_https_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "HTTPRoute"
    metadata = {
      name = "redirect"
      namespace = "default"         
    }
    spec = {
      parentRefs = [
        {
          name        = "mygateway1-regional"
          sectionName = "http"
        }
      ]
      rules = [
        {
          filters = [
            {
              type           = "RequestRedirect"
              requestRedirect = {
              scheme = "https"
              }
            }
          ]
        }
      ]
    }
  }
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

# Verify Certificate Manager SSL Certificate
Go to Cloud Certificate Manager

# List Kubernetes Secrets
kubectl get secrets

# Host Entry
35.208.69.211  app1.stacksimplify.com 

# Access Application
http://<DNS-URL> should redirect to https://<DNS-URL>
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








