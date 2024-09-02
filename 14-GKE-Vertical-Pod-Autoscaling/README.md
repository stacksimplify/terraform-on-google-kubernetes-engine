---
title: GCP Google Kubernetes Engine Vertical Pod Autoscaling
description: Implement GKE Cluster Vertical Pod Autoscaling
---

## Step-01: Introduction
- Implement GKE Cluster Vertical Pod Autoscaling

### Pre-requisite: Verify Cluster Autoscaler enabled on default pool
- Verify if CLuster  Autoscaler enabled on default pool
- We already enabled it as part of Cluster Autoscaler demo

## Step-02: Project: p1-gke-private-cluster-autoscaler
### Step-02-01: c6-02-gke-cluster.tf
```hcl
  # Enable Vertical Pod Autoscaling
  vertical_pod_autoscaling {
    enabled = true
  }
```

### step-02-02: Execute Terraform Commands
```t
# Verify VPA enabled
kubectl get crds | grep verticalpodautoscalers

# Change Directory
cd p1-gke-private-cluster-autoscaler

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify VPA enabled
kubectl get crds | grep verticalpodautoscalers
```
### Step-03: Project: p2-k8sresources-yaml-vpa: Review YAML Manifests
### Step-03-01: Review Kubernetes Deployment and Service
- 01-kubernetes-deployment.yaml
- 02-kubernetes-cip-service.yaml

### Step-03-02: 03-vpa-manifest.yaml
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp1-vpa
  namespace: default
spec:
  targetRef:
    kind: Deployment
    name: myapp1-deployment
    apiVersion: apps/v1
  updatePolicy:
    updateMode: Auto
  resourcePolicy:
    containerPolicies:
      - containerName: myapp1-container
        mode: Auto
        controlledResources:
          - cpu
          - memory
        minAllowed:
          cpu: 25m
          memory: 50Mi
        maxAllowed:
          cpu: 100m
          memory: 100Mi
```

### Step-03-03: Deploy Kubernetes Resources
```t
# Deploy Kubernetes Resources
kubectl apply -f p2-k8sresources-yaml-vpa

# List Deployments
kubectl get deploy

# List Pods
kubectl get pods

# List VPA
kubectl get vpa

# Describe VPA
kubectl describe vpa myapp1-vpa
```

### Step-03-04: Enable VPA for myapp1-deployment workload
- Go to GKE -> Workloads -> myapp1-deployment -> Review if VPA enabled or not

### Step-03-05: Clean-Up
```t
# Delete Kubernetes Resources
kubectl delete -f p2-k8sresources-yaml-vpa

# Delete VPA
kubectl get vpa
kubectl delete vpa myapp1-vpa
```


## Step-04: Project-3: p3-k8sresources-terraform-manifests: Terraform Manifests
### Step-04-01: NO changes to following manifests
- **Folder:** p3-k8sresources-terraform-manifests
- c2-01-variables.tf
- c2-02-local-values.tf
- c3-01-remote-state-datasource.tf
- c3-02-providers.tf
- c4-kubernetes-deployment.tf
- terraform.tfvars

### Step-03-02: c1-versions.tf
- Update your Cloud Storage Bucket
```t
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/k8s-demo1"    
  }  
```

### Step-04-03: c5-kubernetes-clusterip-service.tf
```hcl
# Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "cip_service" {
  metadata {
    name = "myapp1-cip-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.myapp1.spec[0].selector[0].match_labels.app
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

### Step-04-04: c6-kubernetes-vpa.tf
```hcl
# Resource: Vertical Pod Autoscaler
# We dont have dedicated Kubernetes resource in terraform for VPA
# We will use Resource: kubernetes_manifest
resource "kubernetes_manifest" "myapp1_vpa" {
  manifest = {
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name      = "myapp1-vpa"
      namespace = "default"
    }
    spec = {
      targetRef = {
        kind       = "Deployment"
        name       = kubernetes_deployment_v1.myapp1.metadata[0].name 
        apiVersion = "apps/v1"
      }
      updatePolicy = {
        updateMode = "Auto"
      }
      resourcePolicy = {
        containerPolicies = [
          {
            containerName       = "myapp1-container"
            mode                = "Auto"
            controlledResources = [
              "cpu",
              "memory"
            ]
            minAllowed = {
              cpu    = "25m"
              memory = "50Mi"
            }
            maxAllowed = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }
        ]
      }
    }
  }
}
```

### Step-4-05: Verify Resources
```t
# Change Directory
cd p3-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# List Deployments
kubectl get deploy

# List Pods
kubectl get pods

# List VPA
kubectl get vpa

## Sample Output
Kalyans-Mac-mini:p3-k8sresources-terraform-manifests kalyanreddy$ kubectl get vpa
NAME         MODE   CPU   MEM    PROVIDED   AGE
myapp1-vpa   Auto   25m   50Mi   True       2m58s
Kalyans-Mac-mini:p3-k8sresources-terraform-manifests kalyanreddy$ 

# Describe VPA
kubectl describe vpa myapp1-vpa
```

## Step-05: Clean-Up
```t
# Delete Kubernetes  Resources
cd p3-k8sresources-terraform-manifests
terraform apply -destroy -auto-approve
rm -rf .terraform* 

# Delete GCP GKE Cluster 
cd p1-gke-private-cluster-autoscaler/
terraform apply -destroy -auto-approve
rm -rf .terraform* 
```


## FOR A QUICK LOAD TEST
```t
# Run Load Test (New Terminal)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://myapp1-cip-service; done"
```