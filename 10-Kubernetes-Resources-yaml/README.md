---
title: GCP Google Kubernetes Engine GKE - Standard Public Cluster
description: Learn to deploy GCP GKE standard public cluster using Terraform
---

## Step-01: Introduction
1. Kubernetes Deployment
2. Kubernetes Load Balancer Service

## Step-02: 01-kubernetes-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment  
metadata: # Dictionary
  name: myapp1-deployment
spec: # Dictionary
  replicas: 2
  selector: 
    matchLabels: 
      app: myapp1
  template:
    metadata: # Dictionary
      name: myapp1-pod
      labels:
        app: myapp1 # Key Value Pairs   
    spec:
      containers: # List
        - name: myapp1-container
          image: ghcr.io/stacksimplify/kubenginx:1.0.0
          ports: 
            - containerPort: 80          
```

## Step-03: 02-kubernetes-loadbalancer-service.yaml
```yaml
apiVersion: v1
kind: Service 
metadata:
  name: myapp1-lb-service
spec:
  type: LoadBalancer # ClusterIp, # NodePort
  selector:
    app: myapp1
  ports: 
    - name: http
      port: 80 # Service Port
      targetPort: 80 # Container Port
```

## Step-04: Deploy Kubernetes manifests and verify
```t
# Configure kubectl cli
gcloud container clusters get-credentials CLUSTER_NAME --region REGION --project PROJECT_ID
gcloud container clusters get-credentials hr-dev-gke-cluster --region us-central1 --project gcplearn9

# Deploy Kubernetes Manifests
kubectp apply -f p2-k8sresources-yaml

# List Kubernetes Deployments
kubectl get deploy

# List Kubernetes Pods
kubectl get pods

# List Kubernetes Services
kubectl get svc

# Access Application
http://<EXTERNAL-IP-FROM-SVC>

# Verify Kubernetes Resources using GKE console
In workloads tab
1. Deployments, Pods and Services
```

## Step-05: Clean-up
```t
# Delete Kubernetes Resources
kubectl delete -f p2-k8sresources-yaml
```
