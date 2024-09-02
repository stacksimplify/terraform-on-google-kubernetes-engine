# Input Variables
# GCP Project
variable "gcp_project" {
  description = "Project in which GCP Resources to be created"
  type = string
  default = ""
}

# GCP Region
variable "gcp_region" {
  description = "Region in which GCP Resources to be created"
  type = string
  default = ""
}


# GKE Cluster Variables
variable "cluster_name" {
  description = "GKE Cluster name"
  type = string
  default = ""
}

variable "autopilot_enabled" {
  description = "GKE Cluster Type: Standard or Autopilot"
  type = bool 
  default = true 
}

variable "network" {
  description = "Network to deploy to. Only one of network or subnetwork should be specified."
  type        = string
  default     = ""
}

variable "subnetwork" {
  description = "Subnet to deploy to. Only one of network or subnetwork should be specified."
  type        = string
  default     = ""
}

variable "enable_private_endpoint" {
  description = "GKE Cluster: enable_private_endpoint"
  type = bool 
  default = false 
}

variable "enable_private_nodes" {
  description = "GKE Cluster: enable_private_nodes"
  type = bool 
  default = true
}

variable "deletion_protection" {
  description = "GKE Cluster: deletion_protection"
  type = bool 
  default = true 
}


# CIDR IP Ranges
variable "subnet_ip_range" {
  description = "Subnet IP range"
  type = string
  default = ""
}

variable "pods_ip_range" {
  description = "Kubernetes Pods IP range"
  type = string
  default = ""
}

variable "services_ip_range" {
  description = "Kubernetes Services IP range"
  type = string
  default = ""
}

variable "master_ip_range" {
  description = "Kubernetes Master IP range"
  type = string
  default = ""
}

# master_authorized_networks_config

variable "master_authorized_ip_range" {
  description = "Allowed master_authorized_networks CIDR Block"
  type = string
  default = ""
}

variable "master_authorized_ip_range_name" {
  description = "Name of master_authorized_networks CIDR Block"
  type = string
  default = ""
}