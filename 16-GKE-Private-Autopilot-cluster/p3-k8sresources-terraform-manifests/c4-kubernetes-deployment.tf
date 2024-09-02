# Kubernetes Deployment Manifest
resource "kubernetes_deployment_v1" "myapp1" {
  metadata {
    name = "myapp1-deployment"
    labels = {
      app = "myapp1"
    }
  } 
 
  spec {
    replicas = 2
    #replicas = 10

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
          # Kubernetes Resources: Requests and Limits
          resources {
            limits = {
              cpu    = "400m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
          }
        }
      }
    }
}

