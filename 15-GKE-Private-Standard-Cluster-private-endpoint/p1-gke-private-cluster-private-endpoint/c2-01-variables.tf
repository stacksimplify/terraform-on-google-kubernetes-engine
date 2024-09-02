# Input Variables
# GCP Project
variable "gcp_project" {
  description = "Project in which GCP Resources to be created"
  type = string
  default = "kdaida123"
}

# GCP Region
variable "gcp_region1" {
  description = "Region in which GCP Resources to be created"
  type = string
  default = "us-east1"
}

# GCP Compute Engine Machine Type
variable "machine_type" {
  description = "Compute Engine Machine Type"
  type = string
  default = "e2-small"
}


# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type = string
  default = "dev"
}

# Business Division
variable "business_divsion" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type = string
  default = "sap"
}

# CIDR IP Ranges
variable "subnet_ip_range" {
  description = "Subnet IP range"
  type = string
  default = "10.129.0.0/20"
}

variable "pods_ip_range" {
  description = "Kubernetes Pods IP range"
  type = string
  default = "10.11.0.0/21"
}

variable "services_ip_range" {
  description = "Kubernetes Services IP range"
  type = string
  default = "10.12.0.0/21"
}

variable "master_ip_range" {
  description = "Kubernetes Master IP range"
  type = string
  default = "10.13.0.0/28"
}