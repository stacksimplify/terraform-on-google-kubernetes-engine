# Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp1" {
  metadata {
    name = "myapp1-deployment"
    labels = {
      app = "myapp1"
    }
  } 
 
  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "myapp1"
      }
    }

    template {
      metadata {
        labels = {
          app = "myapp1"
        }
      }

      spec {
        container {
          image = "ghcr.io/stacksimplify/kubenginx:1.0.0"
          name  = "myapp1-container"
          port {
            container_port = 80
          }
          resources {
            requests = {
              memory = "5Mi"
              cpu    = "25m"
            }
            limits = {
              memory = "50Mi"
              cpu    = "50m"
            }
          }          
          }
        }
      }
    }
}

