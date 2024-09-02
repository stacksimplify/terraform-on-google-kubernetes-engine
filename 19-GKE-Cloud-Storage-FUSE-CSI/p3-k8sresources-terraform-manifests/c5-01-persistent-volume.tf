# Resource: Kubernetes Persistent Volume
resource "kubernetes_persistent_volume" "gcs_fuse_csi_pv" {
  metadata {
    name = "${local.name}-gcs-fuse-csi-pv"
  }
  spec {
    storage_class_name = "dummy-storage-class"
    access_modes       = ["ReadWriteMany"]
    mount_options = ["implicit-dirs"]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_source {
      csi {
        driver       = "gcsfuse.csi.storage.gke.io"
        volume_handle = google_storage_bucket.my_bucket.name
        volume_attributes = {
          gcsfuseLoggingSeverity = "warning"
        }
      }
    }
  }
}

# Outputs
output "my_pv" {
  value = kubernetes_persistent_volume.gcs_fuse_csi_pv.metadata[0].name
}