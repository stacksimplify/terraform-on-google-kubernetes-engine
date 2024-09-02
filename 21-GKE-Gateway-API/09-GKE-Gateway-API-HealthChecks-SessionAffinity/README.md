---
title: GKE with Kubernetes Gateway API - Load Balancer Health Checks
description: Create GCP Application Load Balancer using GKE Kubernetes Gateway API with Health Checks and Session Affinity
---

## Step-01: Introduction
1. Create GCP Application Load Balancer using Kubernetes Gateway API, Static IP for Load Balancer, Self-signed SSL with Google Cloud Certificate Manager, Domain Name based routing 
2. **Approach-1:** Using Kubernetes YAML Manifests
3. **Approach-2:** Using Terraform Manifests

## Step-02: **Approach-1:** Using Kubernetes YAML Manifests
### Step-02-01: NO CHANGES 
1. c1-01-myapp1-deployment.yaml
2. c1-02-myapp1-clusterip-service.yaml
3. c2-01-gateway.yaml
4. c2-02-gateway-http-route.yaml
5. c2-03-gateway-http-to-https-route.yaml

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

### Step-02-04: Create Certificate Manager Regional cert and cert map and cert map entry
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

### Step-02-05: c1-03-myapp1-healthcheck.yaml
```yaml
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: myapp1-lb-healthcheck
  namespace: default
spec:
  default:
    checkIntervalSec: 5
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 2
    logConfig:
      enabled: false # To enable provide true
    config:
      type: HTTP
      httpHealthCheck:
        port: 80
        requestPath: "/index.html"
        response: "Welcome"
  targetRef:
    group: ""
    kind: Service
    name: myapp1-service
```
### Step-02-06: c1-04-session-affinity.yaml
```yaml
apiVersion: networking.gke.io/v1
kind: GCPBackendPolicy
metadata:
  name: myapp1-backend-policy
  namespace: default
spec:
  default:
    sessionAffinity:
      type: GENERATED_COOKIE # or CLIENT_IP
      cookieTtlSec: 50
  targetRef:
    group: ""
    kind: Service
    name: myapp1-service
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

# Verify Health Checks
Go to Compute Engine -> Health checks

# Host Entry
35.208.69.211 app1.stacksimplify.com

# Access Application
http://<DNS-URL> should redirect to https://<DNS-URL>
Observation:
1. Open Developer Tools in browser and verify Cookie
```
### Step-02-11: Clean-up
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
- c4-01-myapp1-deployment.tf
- c4-02-myapp1-clusterip-service.tf
- c5-01-gateway.tf
- c5-02-gateway-http-to-https-route.tf
- c5-03-gateway-http-route.tf
- c6-static-ip.tf
- c7-certificate-manager.tf
- terraform.tfvars


### Step-03-02: c1-versions.tf
- Update your Cloud Storage Bucket
```t
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-gateway-regional-demo1"    
  }  
```

### Step-03-03: c4-03-myapp1-healthcheck.tf
```hcl
resource "kubernetes_manifest" "myapp1_healthcheck_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "HealthCheckPolicy"
    metadata = {
      name      = "myapp1-lb-healthcheck"
      namespace = "default"
    }
    spec = {
      default = {
        checkIntervalSec   = 5
        timeoutSec         = 5
        healthyThreshold   = 2
        unhealthyThreshold = 2
        logConfig = {
          enabled = false  # To enable, provide true
        }
        config = {
          type = "HTTP"
          httpHealthCheck = {
            port        = 80
            requestPath = "/index.html"
            response    = "Welcome"
          }
        }
      }
      targetRef = {
        group = ""
        kind  = "Service"
        name  = kubernetes_service_v1.service.metadata[0].name 
      }
    }
  }
}
```
### Step-03-04: c4-04-myapp1-session-affinity.tf
```hcl
resource "kubernetes_manifest" "myapp1_gcp_backend_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "GCPBackendPolicy"
    metadata = {
      name      = "myapp1-backend-policy"
      namespace = "default"
    }
    spec = {
      default = {
        sessionAffinity = {
          type         = "GENERATED_COOKIE"  # or "CLIENT_IP"
          cookieTtlSec = 50
        }
      }
      targetRef = {
        group = ""
        kind  = "Service"
        name  = kubernetes_service_v1.service.metadata[0].name 
      }
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

# Host Entry
35.208.69.211 app1.stacksimplify.com

# Access Application
http://<DNS-URL> should redirect to https://<DNS-URL>
Observation:
1. Open Developer Tools in browser and verify Cookie
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




