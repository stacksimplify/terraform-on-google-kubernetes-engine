# Kubernetes Service Manifest (Type: Load Balancer)
resource "kubernetes_service_v1" "lb_service" {
  metadata {
    name = "${local.name}-myapp1-lb-service-ar-demo"
  }
  spec {
    selector = {
      app = module.myapp1_deployment.deployment_labels
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