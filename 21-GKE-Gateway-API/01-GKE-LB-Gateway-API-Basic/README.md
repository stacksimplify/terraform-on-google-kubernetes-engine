---
title: GKE with Kubernetes Gateway API - Regional Load Balancers
description: Create GCP Application Load Balancer using GKE Kubernetes Gateway API
---
## Step-01: Pre-requisite-01: VPC should have Regional Proxy Subnet for Regional Application Load Balancers
### Step-01-01: Update c3-vpc.tf
- **File Location:** p1-gke-autopilot-cluster-private/c3-vpc.tf
```hcl
# Resource: Regional Proxy-Only Subnet (Required for Regional Application Load Balancer)
resource "google_compute_subnetwork" "regional_proxy_subnet" {
  name             = "${var.gcp_region1}-regional-proxy-subnet"
  region           = var.gcp_region1
  ip_cidr_range    = "10.142.0.0/24"
  purpose          = "REGIONAL_MANAGED_PROXY"
  network          = google_compute_network.myvpc.id
  role             = "ACTIVE"
}

output "regional_proxy_subnet_id" {
  description = "Regional Proxy Subnet ID"
  value = google_compute_subnetwork.regional_proxy_subnet.id 
}
```
### Step-01-02: Execute Terraform Commands
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

# Verify new subnet created
- Go to VPC -> hr-dev-vpc -> Subnets 
```
## Step-02: Pre-requisite-02: GKE cluster is created and ready
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
## Step-03: Pre-requisite-02: Verify if Gateway API enabled in GKE cluster
- Go to GKE Cluster -> DETAILS Tab -> NETWORKING -> Gateway API	-> Enabled

## Step-04: Demo Introduction
1. Create GCP Application Load Balancer using Kubernetes Gateway API
2. **Approach-1:** Using Kubernetes YAML Manifests
3. **Approach-2:** Using Terraform Manifests

## Step-05: **Approach-1:** Using Kubernetes YAML Manifests
### Step-05-01: 01-myapp1-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment 
metadata: #Dictionary
  name: myapp1-deployment
spec: # Dictionary
  replicas: 2
  selector:
    matchLabels:
      app: myapp1
  template:  
    metadata: # Dictionary
      name: myapp1-pod
      labels: # Dictionary
        app: myapp1  # Key value pairs
    spec:
      containers: # List
        - name: myapp1-container
          image: ghcr.io/stacksimplify/kubenginx:1.0.0
          ports: 
            - containerPort: 80  
          resources:
            requests:
              memory: "5Mi" # 128 MebiByte is equal to 135 Megabyte (MB)
              cpu: "25m" # `m` means milliCPU
            limits:
              memory: "50Mi"
              cpu: "50m"  # 1000m is equal to 1 VCPU core    
```
### Step-05-02: 02-myapp1-clusterip-service.yaml
```yaml
apiVersion: v1
kind: Service 
metadata:
  name: myapp1-service
spec:
  type: ClusterIP # ClusterIP, # NodePort # LoadBalancer
  selector:
    app: myapp1
  ports: 
    - name: http
      port: 80 # Service Port
      targetPort: 80 # Container Port
```
### Step-05-03: 03-gateway.yaml
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
```
### Step-05-04: 04-gateway-http-route.yaml
```yaml
kind: HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: route-external-http
spec:
  parentRefs:
  - kind: Gateway
    name: mygateway1-regional
  rules:
  - backendRefs:
    - name: myapp1-service
      port: 80
      weight: 100
```
### Step-05-05: Deploy and Verify Resources
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
### Step-05-06: Clean-up
```t
# Delete Kubernetes Resources
kubectl delete -f p2-regional-k8sresources-yaml
```

## Step-06: **Approach-2:** Using Terraform Manifests

## Step-06: Project-3: p3-k8sresources-terraform-manifests: Terraform Manifests
### Step-06-01: NO changes to following manifests
- **Folder:** p3-k8sresources-terraform-manifests
- c2-01-variables.tf
- c2-02-local-values.tf
- c3-01-remote-state-datasource.tf
- c3-02-providers.tf
- c4-myapp1-deployment.tf
- terraform.tfvars

### Step-06-02: c1-versions.tf
- Update your Cloud Storage Bucket
```t
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-gateway-regional-demo1"    
  }  
```

### Step-06-03: c5-myapp1-clusterip-service.tf
```hcl
# Kubernetes Service Manifest (Type: ClusterIP)
resource "kubernetes_service_v1" "service" {
  metadata {
    name = "myapp1-service"
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
    type = "ClusterIP"
  }
}
```
### Step-06-04: c6-gateway.tf
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
    }
  }
}

```
### Step-06-05: c7-gateway-http-route.tf
```hcl
resource "kubernetes_manifest" "http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = "route-external-http"
      namespace = "default"      
    }
    spec = {
      parentRefs = [{
        kind = "Gateway"
        name = "mygateway1-regional"
      }]
      rules = [{
        backendRefs = [{
          name = kubernetes_service_v1.service.metadata[0].name 
          port = 80
          weight = 100
        }]
      }]
    }
  }
}
```
### Step-06-06: Execute Terraform Commands
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

### Step-06-07: Verify Kubernetes Resources
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

### Step-06-08: Clean-Up
```t
# Change Directory
cd p3-regional-k8sresources-terraform-manifests

# Terraform Destroy
terraform apply -destroy -auto-approve
```

## Gateway Documentation
- https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.Listener