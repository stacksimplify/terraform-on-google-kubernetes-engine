# Module: Kubernetes Deployment Manifest
module "myapp1_deployment" {
  source = "../../modules/kubernetes_deployment"
  deployment_name = "${local.name}-myapp1"
  app_name_label = "${local.name}-myapp1"
  replicas = 2
}

# Outputs
output "deployment_labels" {
  value = module.myapp1_deployment.deployment_labels
}