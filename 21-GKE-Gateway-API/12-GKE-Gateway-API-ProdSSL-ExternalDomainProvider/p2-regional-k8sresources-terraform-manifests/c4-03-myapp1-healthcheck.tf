resource "kubernetes_manifest" "myapp1_healthcheck_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "HealthCheckPolicy"
    metadata = {
      name      = "myapp1-lb-healthcheck"
      namespace = "default"
    }
    spec = {
      default = {
        checkIntervalSec   = 5
        timeoutSec         = 5
        healthyThreshold   = 2
        unhealthyThreshold = 2
        logConfig = {
          enabled = false  # To enable, provide true
        }
        config = {
          type = "HTTP"
          httpHealthCheck = {
            port        = 80
            requestPath = "/index.html"
            response    = "Welcome"
          }
        }
      }
      targetRef = {
        group = ""
        kind  = "Service"
        name  = kubernetes_service_v1.service.metadata[0].name 
      }
    }
  }
}
