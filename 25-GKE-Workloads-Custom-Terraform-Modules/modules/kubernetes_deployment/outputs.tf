# Terraform Outputs
output "deployment_labels" {
  description = "Kubernetes Deployment Selector Match Labels"
  value = kubernetes_deployment_v1.myapp1.spec[0].selector[0].match_labels.app
}

