# Resource: Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "myapp1_lb_service" {
  metadata {
    name      = "${local.name}-myapp1-lb-service"
  }
  spec {
    type = "LoadBalancer"
    selector = {
      app = kubernetes_deployment_v1.myapp1_deployment.spec[0].selector[0].match_labels.app
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }
}





# Terraform Outputs
output "myapp1_loadbalancer_ip" {
  value = kubernetes_service_v1.myapp1_lb_service.status[0].load_balancer[0].ingress[0].ip
}
