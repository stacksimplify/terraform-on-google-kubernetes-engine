# Resource: Kubernetes Service Account
resource "kubernetes_service_account" "mysa" {
  metadata {
    name      = "${local.name}-mydemosa"
    namespace = kubernetes_namespace.myns.metadata[0].name
  }
}

# Outputs
output "my_serviceaccount" {
  value = kubernetes_service_account.mysa.metadata[0].name 
}