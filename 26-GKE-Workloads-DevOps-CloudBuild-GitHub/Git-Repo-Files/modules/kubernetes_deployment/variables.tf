# Input Variables
variable "deployment_name" {
  type        = string
  description = "(Required) Kubernetes Deployment Name"
}

variable "namespace" {
  type        = string
  description = "(Optional) Kubernetes Deployment Name"
  default     = "default"
}

variable "replicas" {
  type        = number 
  description = "(Required) Number of Replicas"
}

variable "app_name_label" {
  type        = string
  description = "(Required) App Name label"
}

