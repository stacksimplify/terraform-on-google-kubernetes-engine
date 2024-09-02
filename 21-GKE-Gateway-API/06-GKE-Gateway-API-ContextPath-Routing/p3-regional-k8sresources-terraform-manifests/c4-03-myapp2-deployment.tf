# Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp2" {
  metadata {
    name = "myapp2-deployment"
    labels = {
      app = "myapp2"
    }
  }  
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "myapp2"
      }
    }
    template {
      metadata {
        labels = {
          app = "myapp2"
        }
      }
      spec {
        container {
          image = "ghcr.io/stacksimplify/kube-nginxapp2:1.0.0"
          name  = "myapp2-container"
          port {
            container_port = 80
          }
          }
        }
      }
    }
}

