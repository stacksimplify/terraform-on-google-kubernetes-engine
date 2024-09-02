# Resource: Kubernetes Storage Class
resource "kubernetes_storage_class_v1" "gke_sc" {  
  metadata {
    name = "gke-pd-standard-rwo-sc"
  }
  storage_provisioner = "pd.csi.storage.gke.io"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy = "Retain"
  parameters = {
    type = "pd-balanced" # Other Options supported are pd-ssd
  }
}
