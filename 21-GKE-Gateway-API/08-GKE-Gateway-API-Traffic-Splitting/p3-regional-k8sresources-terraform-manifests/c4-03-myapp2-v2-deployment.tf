# Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp1_v2" {
  metadata {
    name = "myapp1-deployment-v2"
    labels = {
      app = "myapp1-v2"
    }
  }  
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "myapp1-v2"
      }
    }
    template {
      metadata {
        labels = {
          app = "myapp1-v2"
        }
      }
      spec {
        container {
          image = "ghcr.io/stacksimplify/kubenginx:2.0.0"
          name  = "myapp1-container-v2"
          port {
            container_port = 80
          }
          }
        }
      }
    }
}

