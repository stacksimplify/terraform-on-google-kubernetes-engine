---
title: GCP Google Cloud Platform - Implement Continuous Integrationf for a Dockerized App
description: Learn to Implement Continuous Integrationf for a Dockerized App using Artifact Registry, Cloud Build and GitHub
---

## Step-01: Introduction
- Implement Continuous Integration for our application myapp1
- GCP Artifact Registry
- GCP Cloud Build
- GitHub Repository
- GitHub Cloud Build Application from GitHub Marketplace
### GitHub Reposotories
- **GKE Infrastructure Gitrepo:** terraform-gcp-gke-infra-devops
- **Kubernetes manifests Gitrepo:** terraform-gcp-gke-k8s-devops
- **Application Gitrepo:** terraform-gcp-gke-app-devops


## Step-02: Create Artifact Registry
- Go to Google Cloud -> Artifact Registry - **CREATE**
- **Name:** myapps-repository
- **Format:** Docker
- **Mode:** Remote
- **Location type:** Region
- **Region:** us-central1
- REST ALL LEAVE TO DEFAULTS
- Click on **CREATE**

## Step-03: Review or Create GIT Repo Files
### Step-03-01: Dockerfile
```
FROM nginx
COPY index.html /usr/share/nginx/html
```
### Step-03-02: index.html
```html
<!DOCTYPE html>
<html>
   <body style="background-color:rgb(200, 145, 130);">
      <h1>Welcome to StackSimplify</h1>
      <p>Google Kubernetes Engine</p>
      <p>Application Version: V601</p>
   </body>
</html>
```
### Step-03-03: cloudbuild.yaml
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
```

## Step-04: GitHub: Create new GitHub Repository
- Go to GitHub -> Repositories Tab -> Click on **NEW**
- **Repository name:** terraform-gcp-gke-app-devops
- **Description:** Implement Continuous Integration for a simple application
- **Type:** Private
- **Initialize this repository with:** Add a README file
- Click on **Create Repository** 

## Step-05: Local Desktop: Clone GitRepo and Update all the files dicussed in Step-02
```t
# Clone GitHub Repository
git clone git@github.com:stacksimplify/terraform-gcp-gke-app-devops.git

# Copy Files from "GIT-Repo-Files" folder
1. Dockerfile
2. index.html
3. cloudbuild.yaml
4. .gitignore
5. git-deploy.sh

# Commit and Push files to remote git repo
git status
git add .
git commit -am "Base commit"
git push
```

## Step-06: GitHub: Configure GCP Cloud Build on GitHub [IGNORE - IF ALREADY CONFIGURED]
- Go to link [GitHub Marketplace - Google Cloud Build](https://github.com/marketplace/google-cloud-build)
- Click on **Set up with Google Cloud Build**
- **Only select repositories:** stacksimplify/terraform-gcp-gke-app-devops
- Click on **Install**
- Login to Google Cloud and Click on **Authorize Google Cloud Build**
- **Select project in GCP:** gcplearn9
- IF ALREADY CONFIGURED, PLEASE IGNORE THIS STEP

## Step-07: GCP Cloud Build: Create HOST Connection [IGNORE - IF ALREADY CONFIGURED]
- Go to Cloud Build -> Repositories -> 2nd Gen -> **CREATE HOST CONNECTION**
- **Select Provider:** GitHub
- **Configure Connection:** 
  - **Region:** us-central1
  - **Name:** myapp1-workloads
  - Click on **CONNECT**
  - Click on **CONTINUE**
  - **Use an existing GitHub installation:** 
    - **Installation:** stacksimplify
    - Click on **CONFIRM**
- IF ALREADY CONFIGURED, PLEASE IGNORE THIS STEP    

## Step-08: GCP Cloud Build: Link Repository
- Go to Cloud Build -> Repositories -> 2nd Gen -> myapp1-workloads -> **LINK REPOSITORY** 
- **Connection:** myapp1-workloads
- **Repository:** stacksimplify/terraform-gcp-gke-app-devops
- **Repository name:** Generated
- Click on **LINK**

## Step-09: GCP Cloud Build: Create Trigger
- Go to Cloud Build -> Triggers -> **CREATE TRIGGER**
- **Name:** myapp1-ci
- **Region:** us-central1
- **Description:** My App1 Continuous Integration trigger
- **Event:**
  - **Repository event that invokes trigger:** Push to a branch
- **Source:** 
  - **Repository generation:** 2nd gen
  - **Repository:** stacksimplify-terraform-gcp-gke-app-devops
  - **Branch:** .* (any branch)
- **Configuration:** 
  - **Type:** Cloud Build configuration file (yaml or json)
- **Location:** 
  - **Repository:** stacksimplify-terraform-gcp-gke-app-devops (GitHub)
  - **Cloud Build configuration file location:** cloudbuild.yaml
- **Advanced:**
  - **Approval:** Require approval before build executes
- REST ALL LEAVE TO DEFAULTS
- Click on **CREATE**


## Step-10: Run the first build
### Step-10-01: Verify Build process
- Go to Cloud Build -> Triggers -> myapp1-ci -> RUN
- Verify Build progress
- Go to Cloud Build -> History -> APPROVE 
- Verify BUILD PROGRESS AND STEPS
### Step-10-02: Verify Docker Image in Artifact Registry
- Go to Artifact Registry -> myapps-repository -> myapp1
- Verify the new docker image tag

## Step-11: Deploy this Docker Image on GKE Dev Cluster
### Step-11-01: Update modules/kubernetes_deployment/main.tf
- Update Docker Image path and tag in **main.tf**
```hcl
# Before
image = "us-central1-docker.pkg.dev/GOOGLE_CLOUD_PROJECT/myapps-repository/myapp1:COMMIT_SHA"

# Replace GOOGLE_CLOUD_PROJECT,  COMMIT_SHA
image = "us-central1-docker.pkg.dev/gcplearn9/myapps-repository/myapp1:xxxxx"
```
### Step-11-02: Execute Terraform Commands and Verify
```t
# Change Directory
cd p2-k8sresources-terraform-manifests

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify the deployed application
http://<LOAD-BALANCER-IP>
Observation: 
1. V1 App displayed
```

## Step-12: Make changes to App and Check-in code and Verify second build
- Go to Github repo -> terraform-gcp-gke-app-devops > Update **index.html**
```html
<!DOCTYPE html>
<html>
   <body style="background-color:rgb(200, 145, 130);">
      <h1>Welcome to StackSimplify</h1>
      <p>Google Kubernetes Engine</p>
      <p>Application Version: V2</p>
   </body>
</html>
```
- Check-in code
```t
# Check-in code
git add .
git commit -am "V2 Commit"
git push
```


## Step-12: Verify the second build and Docker Image in Artifact Registry
- Go to Artifact Registry -> myapps-repository -> myapp1
- Verify the new docker image tag


## Step-13: Deploy this Docker Image on GKE Dev Cluster
### Step-13-01: Update modules/kubernetes_deployment/main.tf
- Update Docker Image path and tag in **main.tf**
```hcl
# Before
image = "us-central1-docker.pkg.dev/GOOGLE_CLOUD_PROJECT/myapps-repository/myapp1:COMMIT_SHA"

# Replace GOOGLE_CLOUD_PROJECT,  COMMIT_SHA
image = "us-central1-docker.pkg.dev/gcplearn9/myapps-repository/myapp1:xxxxx"
```
### Step-13-02: Execute Terraform Commands and Verify
```t
# Change Directory
cd p2-k8sresources-terraform-manifests

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify the deployed application
http://<LOAD-BALANCER-IP>
Observation: 
1. V2 App displayed
2. Continuous Integration is working as expected
3. How to also implement continous delivery ?
4. Automatically main.tf should be updated with COMMIT_SHA and put ready for deployment
5. We will se that in next demo
```

## Step-14: Clean-up
```t
# Change Directory
cd p2-k8sresources-terraform-manifests

# Terraform Destroy
terraform apply -destroy -auto-approve
```




