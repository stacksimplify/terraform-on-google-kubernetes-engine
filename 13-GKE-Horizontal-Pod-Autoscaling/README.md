---
title: GCP Google Kubernetes Engine Horizontal Pod Autoscaling
description: Implement GKE Cluster Horizontal Pod Autoscaling
---

## Step-01: Introduction
- Implement a Sample Demo with Horizontal Pod Autoscaler

## Step-02: YAML Manifests: Review Kubernetes Manifests
- **Folder:** p3-k8sresources-yaml-autoscaler-v2
- Primarily review `HorizontalPodAutoscaler` Resource in file `p3-k8sresources-yaml-autoscaler-v2/03-kubernetes-hpa.yaml`
1. 01-kubernetes-deployment.yaml
2. 02-kubernetes-cip-service.yaml
3. 03-kubernetes-hpa.yaml
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp1-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp1-deployment
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 30
```

## Step-03: Project-4: p4-k8sresources-terraform-manifests: Terraform Manifests
### Step-03-01: NO changes to following manifests
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

### Step-03-03: c5-kubernetes-clusterip-service.tf
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

### Step-03-04: c6-kubernetes-hpa.tf
```hcl
# Resource: Horizontal Pod Autoscaler V2
resource "kubernetes_horizontal_pod_autoscaler_v2" "cpu_autoscaler" {
  metadata {
    name = "myapp1-hpa" 
  }

  spec {
    min_replicas = 1
    max_replicas = 10

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.myapp1.metadata[0].name 
    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type               = "Utilization"
          average_utilization = 30
        }
      }
    }
  }
}
```
### Step-03-05: Execute Terraform Commands
```t
# Change Directory
cd p4-k8sresources-terraform-manifests

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
# List Pods
kubectl get pods
Observation: 
1. Currently only 1 pod is running

# List HPA
kubectl get hpa

# Run Load Test (New Terminal)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://myapp1-cip-service; done"

# List Pods (SCALE UP EVENT)
kubectl get pods
Observation:
1. New pods will be created to reduce the CPU spikes

# kubectl top command
kubectl top pod

# List HPA (after few mins - approx 3 to 5 mins)
kubectl get hpa --watch

# List Pods (SCALE IN EVENT)
kubectl get pods
Observation:
1. Only 1 pod should be running when there is no load on the workloads
```

## Step-04: Clean-Up
```t
# Delete Load Generator Pod which is in Error State
kubectl delete pod load-generator

# Change Directory
cd p4-k8sresources-terraform-manifests

# Terraform Destroy
terraform apply -destroy -auto-approve
```

## References
- https://cloud.google.com/kubernetes-engine/docs/concepts/horizontalpodautoscaler
- https://cloud.google.com/kubernetes-engine/docs/how-to/horizontal-pod-autoscaling
