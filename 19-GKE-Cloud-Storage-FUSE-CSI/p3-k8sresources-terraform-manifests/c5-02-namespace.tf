# Resource: Kubernetes Namespace
resource "kubernetes_namespace" "myns" {
  metadata {
    name = "${local.name}-mydemo-ns"
  }
}

# Outputs
output "my_namespace" {
  value = kubernetes_namespace.myns.metadata[0].name 
}