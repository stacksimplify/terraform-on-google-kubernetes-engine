# Resource: Horizontal Pod Autoscaler V2
resource "kubernetes_horizontal_pod_autoscaler_v2" "cpu_autoscaler" {
  metadata {
    name = "myapp1-hpa" 
  }

  spec {
    min_replicas = 1
    max_replicas = 10

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.myapp1.metadata[0].name 
    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type               = "Utilization"
          average_utilization = 30
        }
      }
    }
  }
}
