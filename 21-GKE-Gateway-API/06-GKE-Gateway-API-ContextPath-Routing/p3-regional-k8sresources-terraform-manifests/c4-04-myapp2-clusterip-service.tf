# Kubernetes Service Manifest (Type: ClusterIP)
resource "kubernetes_service_v1" "myapp2_service" {
  metadata {
    name = "myapp2-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.myapp2.spec.0.selector.0.match_labels.app
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}
