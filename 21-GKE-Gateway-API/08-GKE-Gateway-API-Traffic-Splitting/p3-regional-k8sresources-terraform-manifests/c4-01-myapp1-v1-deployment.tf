# Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp1_v1" {
  metadata {
    name = "myapp1-deployment-v1"
    labels = {
      app = "myapp1-v1"
    }
  }  
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "myapp1-v1"
      }
    }
    template {
      metadata {
        labels = {
          app = "myapp1-v1"
        }
      }
      spec {
        container {
          image = "ghcr.io/stacksimplify/kubenginx:1.0.0"
          name  = "myapp1-container-v1"
          port {
            container_port = 80
          }
          }
        }
      }
    }
}

