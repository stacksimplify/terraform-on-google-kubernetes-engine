resource "kubernetes_pod_v1" "filestore_writer_app" {
  metadata {
    name = "${local.name}-filestore-writer-app"
  }
  spec {
    container {
      name  = "app"
      image = "centos"
      command = ["/bin/sh"]
      args    = ["-c", "while true; do echo GCP Cloud FileStore used as PV in GKE $(date -u) >> /data/myapp1.txt; sleep 5; done"]
      volume_mount {
        name       = "my-filestore-storage"
        mount_path = "/data"
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
