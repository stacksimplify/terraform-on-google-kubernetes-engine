---
title: GCP Google Cloud Platform - Implement DevOps for GKE Terraform Code in GCP
description: Learn to implement DevOps for GKE Terraform Code in GCP
---

## Step-01: Introduction
- Implement DevOps pipeline using 
  - GitHub 
  - GCP Cloud Build App for GitHub 
  - GCP Cloud Build Service
- We are going to use dev and prod environments in this demo. You can extend it to as many environments as needed. 
- We are going to use Terraform Modules concept for a GKE Cluster which needs changes that will be implemented via DevOps Pipeline using GCP Cloud Build  

## Step-02: Review or Create GIT Repo Files
### Step-02-01: Modules Folder
- Copy the **modules folder** from previous demo (Section: 23-GKE-Infra-Custom-Terraform-Modules)

### Step-02-02: Dev environment in Environments Folder: dev
1. Copy the **terraform-manifests folder** from previous demo (Section: 23-GKE-Custom-Terraform-Modules) and rename folder to dev (envirionments/dev)
2. **envirionments/dev/c1-versions.tf:** ensure we have the backend block configured as **prefix = "dev/gke-cluster"**
3. **Update your bucket name present in your GCP Account:** `bucket = "terraform-on-gcp-gke"`
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.40.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster"    
  }
}
```
3. **terraform.tfvars:** Ensure environment is **environment     = "dev"**
```hcl
gcp_project     = "gcplearn9"
gcp_region     = "us-central1"
environment     = "dev"
business_divsion = "hr"
subnet_ip_range  = "10.128.0.0/20"
pods_ip_range    = "10.1.0.0/21"
services_ip_range = "10.2.0.0/21"
master_ip_range  = "10.3.0.0/28"
```

### Step-02-03: Prod environment in Environments Folder: prod
1. Copy the **terraform-manifests folder** from previous demo (Section: 23-GKE-Custom-Terraform-Modules) and rename folder to prod (envirionments/prod)
2. **envirionments/prod/c1-versions.tf:** ensure we have the backend block configured as **prefix = "prod/gke-cluster"**
3. **Update your bucket name present in your GCP Account:** `bucket = "terraform-on-gcp-gke"`
```hcl
# Terraform Settings Block
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.40.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "prod/gke-cluster"    
  }
}
```
3. **terraform.tfvars:** Ensure environment is **environment     = "prod"**
```hcl
gcp_project     = "gcplearn9"
gcp_region     = "us-central1"
environment     = "prod"
business_divsion = "hr"
subnet_ip_range  = "10.138.0.0/20"
pods_ip_range    = "10.11.0.0/21"
services_ip_range = "10.22.0.0/21"
master_ip_range  = "10.33.0.0/28"
```
### Step-02-04: Review cloudbuild.yaml
```yaml
steps:
- id: 'branch name'
  name: 'alpine'
  entrypoint: 'sh'  
  args: 
  - '-c'
  - | 
      echo "***********************"
      echo "$BRANCH_NAME"
      echo "***********************"

- id: 'tf init'
  name: 'hashicorp/terraform:1.9.0'
  entrypoint: 'sh'
  args: 
  - '-c'
  - |
      if [ -d "environments/$BRANCH_NAME/" ]; then
        cd environments/$BRANCH_NAME
        terraform init
      else
        for dir in environments/*/
        do 
          cd ${dir}   
          env=${dir%*/}
          env=${env#*/}
          echo ""
          echo "*************** TERRAFORM INIT ******************"
          echo "******* At environment: ${env} ********"
          echo "*************************************************"
          terraform init || exit 1
          cd ../../
        done
      fi 

# [START tf-plan]
- id: 'tf plan'
  name: 'hashicorp/terraform:1.9.0'
  entrypoint: 'sh'
  args: 
  - '-c'
  - | 
      if [ -d "environments/$BRANCH_NAME/" ]; then
        cd environments/$BRANCH_NAME
        terraform plan
      else
        for dir in environments/*/
        do 
          cd ${dir}   
          env=${dir%*/}
          env=${env#*/}  
          echo ""
          echo "*************** TERRAFORM PLAN ******************"
          echo "******* At environment: ${env} ********"
          echo "*************************************************"
          terraform plan || exit 1
          cd ../../
        done
      fi 
# [END tf-plan]

# [START tf-apply]
- id: 'tf apply'
  name: 'hashicorp/terraform:1.9.0'
  entrypoint: 'sh'
  args: 
  - '-c'
  - | 
      if [ -d "environments/$BRANCH_NAME/" ]; then
        cd environments/$BRANCH_NAME      
        terraform apply -auto-approve
      else
        echo "***************************** SKIPPING APPLYING *******************************"
        echo "Branch '$BRANCH_NAME' does not represent an official environment."
        echo "*******************************************************************************"
      fi
# [END tf-apply]      
```

## Step-03: GitHub: Create new GitHub Repository
- Go to GitHub -> Repositories Tab -> Click on **NEW**
- **Repository name:** terraform-gcp-gke-infra-devops
- **Description:** Implement DevOps Pipelines for Terraform Configs on GCP GKE (Google Cloud Platform)
- **Type:** Private
- **Initialize this repository with:** Add a README file
- Click on **Create Repository** 

## Step-04: Local Desktop: Install Git Client and Configure GitHub SSH Keys
- Optional step, if you already familiar with github please ignore
### Step-04-01: Install Git Client
- [Install Git Client](https://git-scm.com/downloads)
```t
# Mac
brew install git

# Windows
1. Download and install
```
### Step-04-02: [Generating a new SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
```t
### STEPS FOR MACOS ###
# Verify if Authentication is successful
ssh -T git@github.com

# Create New SSH Key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Create new SSH Key (If you are using a legacy system that doesn't support the Ed25519 algorithm)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Start SSH Agent
eval "$(ssh-agent -s)"

# Verify if file exists
open ~/.ssh/config

# Create file if doesn't exists
touch ~/.ssh/config

# Open config file, Add below text and save it
vi ~/.ssh/config

## Content in file ~/.ssh/config
Host github.com
  AddKeysToAgent yes
  UseKeychain no
  IdentityFile ~/.ssh/id_ed25519
```
### Step-04-03: [Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account?tool=webui)
- [Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account?tool=webui)
```t
# Copy the content from public key file
cat $HOME/.ssh/id_ed25519.pub

# Go to GitHub -> Settings -> SSH and GPG Keys -> New SSH Key
TITLE: mac-mini-1
KEY: COPY the public key file content (id_ed25519.pub)
```

### Step-04-04: [Testing SSH Connection](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)
- [Testing SSH Connection](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)
```t
# Verify if Authentication is successful
ssh -T git@github.com
```

## Step-05: Local Desktop: Clone GitRepo and Update all the files dicussed in Step-02
```t
# Clone GitHub Repository
git clone git@github.com:stacksimplify/terraform-gcp-gke-infra-devops.git

# Copy Files from "GIT-Repo-Files" folder
1. environmets folder
2. modules folder
3. cloudbuild.yaml
4. .gitignore
5. git-deploy.sh

# Commit and Push files to remote git repo
git status
git add .
git commit -am "Base commit"
git push
```

## Step-06: GitHub: Configure GCP Cloud Build on GitHub
- Go to link [GitHub Marketplace - Google Cloud Build](https://github.com/marketplace/google-cloud-build)
- Click on **Set up with Google Cloud Build**
- **Only select repositories:** stacksimplify/terraform-gcp-gke-infra-devops
- Click on **Install**
- Login to Google Cloud and Click on **Authorize Google Cloud Build**
- **Select project in GCP:** gcplearn9


## Step-07: GCP Cloud Build: Create HOST Connection
- Go to Cloud Build -> Repositories -> 2nd Gen -> **CREATE HOST CONNECTION**
- **Select Provider:** GitHub
- **Configure Connection:** 
  - **Region:** us-central1
  - **Name:** gke-cluster-trigger1
  - Click on **CONNECT**
  - Click on **CONTINUE**
  - **Use an existing GitHub installation:** 
    - **Installation:** stacksimplify
    - Click on **CONFIRM**

## Step-08: GCP Cloud Build: Link Repository
- Go to Cloud Build -> Repositories -> 2nd Gen -> gke-cluster-trigger1 -> **LINK REPOSITORY** 
- **Connection:** gke-cluster-trigger1
- **Repository:** stacksimplify/terraform-gcp-gke-infra-devops
- **Repository name:** Generated
- Click on **LINK**

## Step-09: GCP Cloud Build: Create Trigger
- Go to Cloud Build -> Triggers -> **CREATE TRIGGER**
- **Name:** gke-cluster-trigger1
- **Region:** us-central1
- **Description:** My GKE Cluster Cloud Build Trigger
- **Event:**
  - **Repository event that invokes trigger:** Push to a branch
- **Source:** 
  - **Repository generation:** 2nd gen
  - **Repository:** stacksimplify-terraform-gcp-gke-infra-devops
  - **Branch:** .* (any branch)
- **Configuration:** 
  - **Type:** Cloud Build configuration file (yaml or json)
- **Location:** 
  - **Repository:** stacksimplify-terraform-gcp-gke-infra-devops (GitHub)
  - **Cloud Build configuration file location:** cloudbuild.yaml
- **Advanced:**
  - **Approval:** Require approval before build executes
- REST ALL LEAVE TO DEFAULTS
- Click on **CREATE**

## Step-10: GitHub: Create Dev and Prod branches
- **Pre-requisite:** Please ensure c1-versions.tf in Dev and Prod environments, you have updated your GCP Cloud storage bucket name to store Terraform state files as part of step-02 of this demo
```hcl
# Dev Environment
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "dev/gke-cluster"    
  }
# Prod Environment
  backend "gcs" {
    bucket = "terraform-on-gcp-gke"
    prefix = "prod/gke-cluster"    
  } 
```
- Go to GitHub -> terraform-gcp-gke-infra-devops -> main -> View all branches
- Click on **New branch** 
  - **New branch name:** dev
  - **Source:** main
  - click on **Create new branch**
- Click on **New branch** 
  - **New branch name:** prod
  - **Source:** main
  - click on **Create new branch**

## Step-11: GCP Cloud Build: Approve Dev and Prod base builds
- Go to Cloud Build -> History 
### Step-11-01: Dev Build: Approve
- Approve Dev Build
- Review Build steps (tf init, tf plan, tf apply) and Build Summary
- Verify Terraform State file in Cloud Storage Bucket
- Verify Infra for Dev environment
  - VPC
  - GKE Cluster
  - Cloud NAT and Cloud Router
### Step-11-02: Prod Build: Approve
- Approve Prod Build
- Review Build steps (tf init, tf plan, tf apply) and Build Summary
- Verify Terraform State file in Cloud Storage Bucket
- Verify Infra for prod environment
  - VPC
  - GKE Cluster
  - Cloud NAT and Cloud Router


## Step-12: GitHub: NEW FEATURE BRANCH: Update GKE Cluster with new labels
### Step-12-01: GitHub: Make a change with new branch
- Go to dev branch -> terraform-gcp-gke-infra-devops/modules/gke_cluster
/main.tf -> EDIT IN PLACE
- UNCOMMENT `resource_labels`
```hcl
# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name     = var.cluster_name
  location = var.gcp_region

  # Autopilot Cluster
  enable_autopilot = var.autopilot_enabled
   
  # Network
  network = var.network
  subnetwork = var.subnetwork

  # In production, change it to true (Enable it to avoid accidental deletion)
  deletion_protection = var.deletion_protection

  # Private Cluster Configurations
  private_cluster_config {
    enable_private_endpoint = var.enable_private_endpoint
    enable_private_nodes    = var.enable_private_nodes
    master_ipv4_cidr_block  = var.master_ip_range
  }

  # IP Address Ranges
  ip_allocation_policy {
    cluster_secondary_range_name = var.pods_ip_range
    services_secondary_range_name = var.services_ip_range
  }

  # Allow access to Kubernetes master API Endpoint
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = var.master_authorized_ip_range
      display_name = var.master_authorized_ip_range_name
    }
  }

  # Add Resource labels
  resource_labels = {
    team = "frontend"
  }
  
}
```
- Click on **COMMIT CHANGES**
- **COMMIT MESSAGE:** Update GKE cluster with labels
- **SELECT OPTION:** Create a new branch for this commit and start a pull request
- **NEW BRANCH NAME:** stacksimplify-patch-1
- Click on **Propose changes**
- Click on **Create pull request**
### Step-12-02: GCP Cloud Build: Approve Build for branch: stacksimplify-patch-1
- Go to **Cloud Build** -> **Approve Build**
- Review Build steps (tf init, tf plan, tf apply) and Build Summary
- **Observation:** 
  - **tf plan:** tf plan will run for both dev and prod folders with the change we have made in the branch **stacksimplify-patch-1**
  - **Important Note:** The build checks whether the $BRANCH_NAME variable matches any environment folder. If so, Cloud Build executes `terraform plan` for that environment. Otherwise, Cloud Build executes terraform plan for all environments to make sure that the proposed change is appropriate for all of them. If any of these plans fail to execute, the build fails.
  - Review the plan to see what will happen for both environments (Dev, prod)
  - Based on the label addition change, it will update the GKE cluster. 
  - **tf apply:** tf apply will run only for environment name and branch name matches (example: currently only for dev and prod)
  - **Important Note:** Similarly, the `terraform apply` command runs for environment branches, but it is completely ignored in any other case.

### Step-12-03: GitHub: Verify the Checks on GitHub
- We should see **All checks have passed** message

## Step-13: GitHub: Promote changes to dev environment and Verify changes applied in Dev environment using Cloud Build
### Step-13-01: GitHub: Promote changes to dev environment
- Go to GitHub -> terraform-gcp-gke-infra-devops -> pull requests 
- Click on the pull request just created
- Review statement **stacksimplify wants to merge 1 commit into dev from stacksimplify-patch-1**
- Click on **Merge pull request**
- Click on **Config merge** 
- You should see message **Pull request successfully merged and closed**
- Verify GCP Cloud Build if any build triggered for **dev** branch 
### Step-13-02: GCP Cloud Build: Review and approve Dev Build
- Approve Dev Build
- Review Build steps (tf init, tf plan, tf apply) and Build Summary
- Verify Infra for dev environment
  - GCP GKE Cluster: **Labels will be added**

## Step-14: GitHub: Promote changes to prod environment and Verify changes applied in Prod environment using Cloud Build
### Step-14-01: GitHub: Promote changes to prod environment
- Go to GitHub -> terraform-gcp-gke-infra-devops -> pull requests 
- Click **New pull request** 
- **base:** prod
- **compare:** dev
- Review the changes
- Click on **Create pull request**
- **Title:** Promoting GKE label changes to prod
- Click on **Create pull request**
- Click on **Merge pull request**
- Click on **Confirm merge**
- You should see message **Pull request successfully merged and closed**
- Verify GCP Cloud Build if any build triggered for **prod** branch 

### Step-14-02: GCP Cloud Build: Review and approve Prod Build
- Approve Prod Build
- Review Build steps (tf init, tf plan, tf apply) and Build Summary
- Verify Infra for prod environment
  - GCP GKE Cluster: **Labels will be added**

## Step-05: Clean-Up (DONT CLEAN-UP WE WILL USE LATER DEMOS)
```t
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