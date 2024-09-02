# Resource: Kubernetes Deployment
resource "kubernetes_deployment_v1" "myapp1_deployment" {
  metadata {
    name      = "${local.name}-myapp1-deployment"
    namespace = kubernetes_namespace.myns.metadata[0].name 
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
        annotations = {
          "gke-gcsfuse/volumes" = "true"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.mysa.metadata[0].name 
        container {
          name  = "myapp1-container"
          image = "ghcr.io/stacksimplify/kubenginx:1.0.0"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "gcs-fuse-csi-static"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }
        }
        volume {
          name = "gcs-fuse-csi-static"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.gcs_fuse_csi_static_pvc.metadata[0].name
          }
        }
      }
    }
  }
}
