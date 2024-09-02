# Resource: Kubernetes Deployment
resource "kubernetes_deployment_v1" "myapp1_deployment" {
  metadata {
    name      = "${local.name}-myapp1-deployment"
  }
  spec {
    replicas = 2
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
          name  = "myapp1-container"
          image = "ghcr.io/stacksimplify/kubenginx:1.0.0"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "my-filestore-storage"
            mount_path = "/usr/share/nginx/html/filestore"
          }
        }
        volume {
          name = "my-filestore-storage"
          persistent_volume_claim {            
            claim_name = "${local.name}-filestore-pvc"
          }
        }
      }
    }
  }
}
