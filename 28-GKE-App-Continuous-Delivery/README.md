---
title: GCP Google Cloud Platform - Implement Continuous Integrationf for a Dockerized App
description: Learn to Implement Continuous Integrationf for a Dockerized App using Artifact Registry, Cloud Build and GitHub
---

## Step-01: Introduction
- Implement Continuous Integration for our application myapp1
- Implement Continuous Delivery for our application myapp1
### GitHub Reposotories
- **GKE Infrastructure Gitrepo:** terraform-gcp-gke-infra-devops
- **Kubernetes manifests Gitrepo:** terraform-gcp-gke-k8s-devops
- **Application Gitrepo:** terraform-gcp-gke-app-devops

## Step-02: App Repo: Convert CI cloudbuild.yaml to CD (Continuous Delivery)
### Step-02-01: Create SSH Keys for GitHub Authentication from Cloud Build Trigger
```t
# Change Directory
cd 01-SSH-Keys

# Create SSH Keys
ssh-keygen -t rsa -b 4096 -N '' -f id_github -C <github-email>
ssh-keygen -t rsa -b 4096 -N '' -f id_github -C "stacksimplify@gmail.com"

# Review Private Key: id_gcp_cloud_source
cat id_github

# Review Public Key: id_gcp_cloud_source.pub 
cat id_github.pub
```

### Step-02-02: Create Secret in GCP Secret Manager with SSH Private Key 
- Go to Security -> Secret Manager -> Click on **CREATE SECRET**
- **Name:** mygithub-ssh
- **Upload File:** 01-SSH-Keys/id_github
- REST ALL LEAVE TO DEFAULTS
- Click on **CREATE SECRET**

### Step-02-03: Upload SSH Public Key to GitHub
- Go to Github.com -> Login with your github account -> Settings -> SSH and GPG Keys -> New SSH Key
- **Title:** mygke-cloudbuild-authentication
- **Key Type:** Authentication
- **Key:** COPY PUBLIC SSH KEY from **01-SSH-Keys/id_github.pub**

### Step-02-04: Review main.tf.tpl
- Ensure the following is present **image = "us-central1-docker.pkg.dev/GOOGLE_CLOUD_PROJECT/myapps-repository/myapp1:COMMIT_SHA"**
```hcl
# Resource: Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp1" {
  metadata {
    name = var.deployment_name
    namespace = var.namespace
    labels = {
      app = var.app_name_label
    }
  } 
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = var.app_name_label
      }
    }
    template {
      metadata {
        labels = {
          app = var.app_name_label
        }
      }
      spec {
        container {
          image = "us-central1-docker.pkg.dev/GOOGLE_CLOUD_PROJECT/myapps-repository/myapp1:COMMIT_SHA"
          name  = "myapp1-container"
          port {
            container_port = 80
          }
          }
        }
      }
    }
}
```

### Step-02-05: Create known_hosts file
- Get the public key of **github.com** and save it in **known_hosts.github**
```t
# Create known_hosts
ssh-keyscan -t rsa github.com > known_hosts.github
```
### Step-02-06: Review cloudbuild.yaml
```yaml
# [START cloudbuild - Docker Image Build]
steps:
# This step builds the container image.
- name: 'gcr.io/cloud-builders/docker'
  id: Build Docker Image
  args:
  - 'build'
  - '-t'
  - 'us-central1-docker.pkg.dev/$PROJECT_ID/myapps-repository/myapp1:$SHORT_SHA'
  - '.'

# This step pushes the image to Artifact Registry
# The PROJECT_ID and SHORT_SHA variables are automatically
# replaced by Cloud Build.
- name: 'gcr.io/cloud-builders/docker'
  id: Push Docker Image
  args:
  - 'push'
  - 'us-central1-docker.pkg.dev/$PROJECT_ID/myapps-repository/myapp1:$SHORT_SHA'
# [END cloudbuild - Docker Image Build]


# [START cloudbuild-trigger-cd]
# This step clones the terraform-gcp-gke-k8s-devops repository
- name: 'gcr.io/cloud-builders/git'
  id: Extract Private SSH key from GCP Secrets Manager
  secretEnv: ['SSH_KEY']
  entrypoint: 'bash'
  args:
  - -c
  - |
    echo "$$SSH_KEY"
    echo "$$SSH_KEY" >> /root/.ssh/id_rsa
    chmod 400 /root/.ssh/id_rsa
    cp known_hosts.github /root/.ssh/known_hosts
  volumes:
  - name: 'ssh'
    path: /root/.ssh    

# This step clones the terraform-gcp-gke-k8s-devops repository
- name: 'gcr.io/cloud-builders/gcloud'
  id: Clone terraform-gcp-gke-k8s-devops repository
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    git clone git@github.com:stacksimplify/terraform-gcp-gke-k8s-devops.git
    cd terraform-gcp-gke-k8s-devops && \
    git config user.email $(gcloud auth list --filter=status:ACTIVE --format='value(account)')
  volumes:
  - name: 'ssh'
    path: /root/.ssh


# This step generates the new manifest
- name: 'gcr.io/cloud-builders/gcloud'
  id: Generate Kubernetes manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
     sed "s/GOOGLE_CLOUD_PROJECT/${PROJECT_ID}/g" main.tf.tpl | \
     sed "s/COMMIT_SHA/${SHORT_SHA}/g" > terraform-gcp-gke-k8s-devops/modules/kubernetes_deployment/main.tf
  volumes:
  - name: 'ssh'
    path: /root/.ssh

# This step pushes the manifest back to terraform-gcp-gke-k8s-devops
- name: 'gcr.io/cloud-builders/gcloud'
  id: Push Kubernetes manifests to terraform-gcp-gke-k8s-devops repo
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \
    cd terraform-gcp-gke-k8s-devops && \
    git add modules/kubernetes_deployment/main.tf && \
    git commit -m "Updating image us-central1-docker.pkg.dev/$PROJECT_ID/myapps-repository/myapp1:${SHORT_SHA}
    Built from commit ${COMMIT_SHA} of repository terraform-gcp-gke-k8s-devops
    Author: $(git log --format='%an <%ae>' -n 1 HEAD)" && \
    git push origin main
  volumes:
  - name: 'ssh'
    path: /root/.ssh

availableSecrets:
  secretManager:
  - versionName: projects/$PROJECT_ID/secrets/mygithub-ssh/versions/latest
    env: 'SSH_KEY'

# [END cloudbuild-trigger-cd]
```
### Step-02-06: VERY IMPORTANT: Update Cloud Build Settings Service Account to access GCP Secrets Manager
- Go to Cloud Build -> Settings-> Secret Manager (Role: Secret Manager Secret Accessor) -> ENABLED

### Step-02-07: Update index.html
```html
<!DOCTYPE html>
<html>
   <body style="background-color:rgb(200, 145, 130);">
      <h1>Welcome to StackSimplify</h1>
      <p>Google Kubernetes Engine</p>
      <p>Application Version: V3</p>
   </body>
</html>
```

### Step-02-08: Git Push and Commit
```t
# Git Commit and Push
git commit -am "V3 Commit"
git push
```

### Step-02-09: Verify and Approve myapp1-ci build
- Go to Cloud Build -> History -> Approve build -> verify build steps

### Step-02-10: Verif7 k8s repo
- This repo is already setup as part of **Demo:38-GKE-Workloads-DevOps-CloudBuild-GitHub**
- Go to Git repo terraform-gcp-gke-k8s-devops -> modules/main.tf
- Ensure new Docker tag is updated

### Step-02-11: Verify and Approve myapp1-cd build
- Go to Cloud Build -> History -> Approve build -> verify build steps
- Changes will be applied in Git repo terraform-gcp-gke-k8s-devops -> main branch

## Step-03: V3 Build Apply to Dev and Prod Environments
### Step-03-01: Dev Environment
- Go to GitHub -> terraform-gcp-gke-k8s-devops
- Follow the Pull Request Approach
  - Merge from main to dev branch
  - Approve build in Cloud Build
  - Verify build Steps
- Access Dev Application
```t
# Dev Application
http://<DEV-LB-IP>
```  
### Step-03-02: Prod Environment
- Go to GitHub -> terraform-gcp-gke-k8s-devops
- Follow the Pull Request Approach
  - Merge from dev to prod branch
  - Approve build in Cloud Build
  - Verify build Steps
- Access Prod Application
```t
# Prod Application
http://<PROD-LB-IP>
```  

## Step-04: Try V4 build one more time
1. Update App Repo index.html to V4
2. Commit and Push to github
3. Approve the myapp1-ci build
4. Approve the myapp1-cd build
5. Follow pull request approach on k8s repo from main to dev repo, dev to prod repo

## Step-05: Clean-Up
```t
# Delete App - Dev
cd terraform-gcp-gke-k8s-devops
cd environments/dev
terraform init
terraform apply -destroy -auto-approve

# Delete App - Prod
cd terraform-gcp-gke-k8s-devops
cd environments/prod
terraform init
terraform apply -destroy -auto-approve

# Delete GKE Cluster - Dev
cd terraform-gcp-gke-infra-devops
cd environments/dev
terraform init
terraform apply -destroy -auto-approve

# Delete GKE Cluster - Prod
cd terraform-gcp-gke-infra-devops
cd environments/prod
terraform init
terraform apply -destroy -auto-approve
```