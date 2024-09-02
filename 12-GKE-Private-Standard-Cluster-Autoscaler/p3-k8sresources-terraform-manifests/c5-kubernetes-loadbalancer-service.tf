# Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "lb_service" {
  metadata {
    name = "myapp1-lb-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.myapp1.spec.0.selector.0.match_labels.app
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}

# Terraform Outputs
output "myapp1_loadbalancer_ip" {
  value = kubernetes_service_v1.lb_service.status[0].load_balancer[0].ingress[0].ip
}