---
title: GKE Storage with GCP File Store - Custom StorageClass
description: Use GCP File Store for GKE Workloads with Custom StorageClass
---

## Step-01: Introduction
- GKE Storage with GCP File Store - Custom StorageClass
- Implement using YAML Manifests: p2-k8sresources-yaml
- Implement using Terraform Manifests: p3-k8sresources-terraform-manifests


## Step-02: Enable Filestore CSI driver	(If not enabled)
- Go to Kubernetes Engine -> standard-cluster-private -> Details -> Features -> Filestore CSI driver	
- Click on Checkbox **Enable Filestore CSI Driver**
- Click on **SAVE CHANGES**
- **Important Note:** By default enabled in Autopilit clusters

## Step-03: Verify if Filestore CSI Driver enabled
```t
# Verify Filestore CSI Daemonset in kube-system namespace
kubectl -n kube-system get ds | grep file
Observation: 
1. You should find the Daemonset with name "filestore-node"

# Verify Filestore CSI Daemonset pods in kube-system namespace
kubectl -n kube-system get pods | grep file
Observation: 
1. You should find the pods with name "filestore-node-*"
```

## Step-04: Storage Classes created by default when cluster created
- After you enable the Filestore CSI driver, GKE automatically installs the following StorageClasses for provisioning Filestore instances:
- **standard-rwx:** using the Basic HDD Filestore service tier
- **premium-rwx:** using the Basic SSD Filestore service tier
- **enterprise-rwx:** enterprise-grade workloads that require high performance and reliability. It provides significantly higher IOPS and throughput compared to the Basic tiers, making it suitable for mission-critical applications
  - High-performance computing (HPC), 
  - databases, 
  - big data analytics, and any application requiring high IOPS and low latency.
- **enterprise-multishare-rwx:** High performance, multi-share capability, ideal for complex, multi-tenant environments.
  - **Performance:** This is an advanced service tier under the Enterprise category that allows a single Filestore instance to support multiple shares. It combines the high performance of the enterprise tier with the flexibility of managing multiple file shares within a single instance.
  **Typical Use Cases:**  Multi-tenant environments, applications requiring multiple isolated file shares (e.g., different departments or teams within an organization), scalable shared storage solutions for containerized environments.
```t
# Default Storage Class created as part of FileStore CSI Enablement
kubectl get sc
Observation: Below two storage class will be created by default
standard-rwx
premium-rwx 
enterprise-rwx
enterprise-multishare-rwx
```

## Step-05: Project-2: YAML Manifests
- **Project Folder:** p2-k8sresources-yaml
### Step-05-01: 00-filestore-storage-class.yaml
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore-storage-class
provisioner: filestore.csi.storage.gke.io # File Store CSI Driver
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  tier: standard # Allowed values standard, premium, or enterprise
  network: hr-dev-vpc # The network parameter can be used when provisioning Filestore instances on non-default VPCs. Non-default VPCs require special firewall rules to be set up.
```
### Step-05-02: 01-filestore-pvc.yaml
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: gke-filestore-pvc
spec:
  accessModes:
  - ReadWriteMany
  storageClassName: filestore-storage-class
  resources:
    requests:
      storage: 1Ti
```
### Step-05-03: 02-write-to-filestore-pod.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: filestore-writer-app
spec:
  containers:
    - name: app
      image: centos
      command: ["/bin/sh"]
      args: ["-c", "while true; do echo GCP Cloud FileStore used as PV in GKE $(date -u) >> /data/myapp1.txt; sleep 5; done"]
      volumeMounts:
        - name: my-filestore-storage
          mountPath: /data
  volumes:
    - name: my-filestore-storage
      persistentVolumeClaim:
        claimName: gke-filestore-pvc
```
### Step-05-04: 03-myapp1-deployment.yaml
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
          volumeMounts:
            - name: persistent-storage
              mountPath: /usr/share/nginx/html/filestore
      volumes:
        - name: persistent-storage
          persistentVolumeClaim:
            claimName: gke-filestore-pvc                
```
### Step-05-05: 04-loadBalancer-service.yaml
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
### Step-05-06: Deploy kube-manifests
```t
# Deploy kube-manifests
kubectl apply -f kube-manifests/

# List Storage Class
kubectl get sc

# List PVC
kubectl get pvc

# List PV
kubectl get pv

# List Pods
kubectl get pods
``` 

### Step-05-07:Verify GCP Cloud FileStore Instance
- Go to FileStore -> Instances
- Click on **Instance ID: pvc-27cd5c27-0ed0-48d1-bc5f-925adfb8495f**
- **Note:** Instance ID dynamically generated, it can be different in your case starting with pvc-*

### Step-05-08:Connect to filestore write app Kubernetes pods and Verify
```t
# FileStore write app - Connect to Kubernetes Pod
kubectl exec --stdin --tty <POD-NAME> -- /bin/sh
kubectl exec --stdin --tty filestore-writer-app  -- /bin/sh
cd /data
ls
tail -f myapp1.txt
exit
```

### Step-05-09:Connect to myapp1 Kubernetes pods and Verify
```t
# List Pods
kubectl get pods 

# myapp1 POD1 - Connect to Kubernetes Pod
kubectl exec --stdin --tty <POD-NAME> -- /bin/sh
kubectl exec --stdin --tty myapp1-deployment-5d469f6478-2kp97 -- /bin/sh
cd /usr/share/nginx/html/filestore
ls
tail -f myapp1.txt
exit

# myapp1 POD2 - Connect to Kubernetes Pod
kubectl exec --stdin --tty <POD-NAME> -- /bin/sh
kubectl exec --stdin --tty myapp1-deployment-5d469f6478-2kp97  -- /bin/sh
cd /usr/share/nginx/html/filestore
ls
tail -f myapp1.txt
exit
```

### Step-05-10: Access Application
```t
# List Services
kubectl get svc

# Access Application
http://<EXTERNAL-IP-OF-GET-SERVICE-OUTPUT>/filestore/myapp1.txt
http://35.232.145.61/filestore/myapp1.txt
curl http://35.232.145.61/filestore/myapp1.txt
```


### Step-05-11: Clean-Up
```t
# Delete Kubernetes Objects
kubectl delete -f kube-manifests/

# Verify if FileStore Instance is deleted
Go to -> FileStore -> Instances
```

## Step-06: Project-3: Terraform manifests
- **Project Folder:** p3-k8sresources-terraform-manifests

### Step-06-01: c1-versions.tf
- Update Cloud storage bucket created in your GCP account
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.40.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.31"
    }      
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/filestore-demo"    
  }  
}

```
### Step-06-02: NO CHANGES
- c2-01-variables.tf
- c2-02-local-values.tf
- c3-02-providers.tf

### Step-06-03: c3-01-remote-state-datasource.tf
- Update Cloud Storage bucket from your GCP Account for Project-1: GKE cluster
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
### Step-06-04: c4-01-storage-class.tf
```hcl
# Resource: Kubernetes Storage Class
resource "kubernetes_storage_class_v1" "filestore_sc" {
  metadata {
    name = "my-gke-filestore-sc"    
  }
  storage_provisioner = "filestore.csi.storage.gke.io" # File Store CSI Driver
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    tier = "standard"
    network = data.terraform_remote_state.gke.outputs.vpc_name
  }
}

```
### Step-06-05: c4-02-persistent-volume-claim.tf
```hcl
# Resource: Persistent Volume Claim
resource "kubernetes_persistent_volume_claim_v1" "filestore_pvc" {
  metadata {
    name      = "${local.name}-filestore-pvc"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.filestore_sc.metadata[0].name 
    resources {
      requests = {
        storage = "1Ti"
      }
    }
  }
  timeouts {
    create = "20m"
  }
}

# Outputs
output "filestore_pvc" {
  value =  kubernetes_persistent_volume_claim_v1.filestore_pvc.metadata[0].name
}
```
### Step-06-06: c5-01-write-to-filestore-pod.tf
```hcl
resource "kubernetes_pod_v1" "filestore_writer_app" {
  metadata {
    name = "${local.name}-filestore-writer-app"
  }
  spec {
    container {
      name  = "app"
      image = "centos"
      command = ["/bin/sh"]
      args    = ["-c", "while true; do echo GCP Cloud FileStore used as PV in GKE $(date -u) >> /data/myapp1.txt; sleep 5; done"]
      volume_mount {
        name       = "my-filestore-storage"
        mount_path = "/data"
      }
    }
    volume {
      name = "my-filestore-storage"
      persistent_volume_claim {
        claim_name = "${local.name}-filestore-pvc"
      }
    }
  }
}

```
### Step-06-07: c5-02-myapp1-deployment.tf
```hcl
# Resource: Kubernetes Deployment
resource "kubernetes_deployment_v1" "myapp1_deployment" {
  metadata {
    name      = "${local.name}-myapp1-deployment"
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
      }
      spec {
        container {
          name  = "myapp1-container"
          image = "ghcr.io/stacksimplify/kubenginx:1.0.0"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "my-filestore-storage"
            mount_path = "/usr/share/nginx/html/filestore"
          }
        }
        volume {
          name = "my-filestore-storage"
          persistent_volume_claim {            
            claim_name = "${local.name}-filestore-pvc"
          }
        }
      }
    }
  }
}

```
### Step-06-08: c5-03-myapp1-loadbalancer-service.tf
```hcl
# Resource: Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "myapp1_lb_service" {
  metadata {
    name      = "${local.name}-myapp1-lb-service"
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
### Step-06-09: Execute Terraform Commands
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

### Step-06-10: Verify Kubernetes Resources
```t
# List Storage Class
kubectl get sc

# List PVC
kubectl get pvc

# List PV
kubectl get pv

# List Pods
kubectl get pods
``` 

### Step-06-11: Verify GCP Cloud FileStore Instance
- Go to FileStore -> Instances
- Click on **Instance ID: pvc-27cd5c27-0ed0-48d1-bc5f-925adfb8495f**
- **Note:** Instance ID dynamically generated, it can be different in your case starting with pvc-*

### Step-06-12: Connect to filestore write app Kubernetes pods and Verify
```t
# FileStore write app - Connect to Kubernetes Pod
kubectl exec --stdin --tty <POD-NAME> -- /bin/sh
kubectl exec --stdin --tty hr-dev-filestore-writer-app  -- /bin/sh
cd /data
ls
tail -f myapp1.txt
exit
```

 ### Step-06-13: Connect to myapp1 Kubernetes pods and Verify
```t
# List Pods
kubectl get pods 

# myapp1 POD1 - Connect to Kubernetes Pod
kubectl exec --stdin --tty <POD-NAME> -- /bin/sh
kubectl exec --stdin --tty myapp1-deployment-5d469f6478-2kp97 -- /bin/sh
cd /usr/share/nginx/html/filestore
ls
tail -f myapp1.txt
exit

# myapp1 POD2 - Connect to Kubernetes Pod
kubectl exec --stdin --tty <POD-NAME> -- /bin/sh
kubectl exec --stdin --tty myapp1-deployment-5d469f6478-2kp97  -- /bin/sh
cd /usr/share/nginx/html/filestore
ls
tail -f myapp1.txt
exit
```

### Step-06-14: Access Application
```t
# List Services
kubectl get svc

# Access Application
http://<EXTERNAL-IP-OF-GET-SERVICE-OUTPUT>/filestore/myapp1.txt
http://35.232.145.61/filestore/myapp1.txt
curl http://35.232.145.61/filestore/myapp1.txt
```

### Step-06-15: Clean-Up
```t
# Change Directory
cd p3-k8sresources-terraform-manifests

# Terraform Destroy
terraform apply -destroy -auto-approve
```
