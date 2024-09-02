# Resource: Kubernetes Storage Class
resource "kubernetes_storage_class_v1" "filestore_sc" {
  metadata {
    name = "my-gke-filestore-sc"    
  }
  storage_provisioner = "filestore.csi.storage.gke.io" # File Store CSI Driver
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    tier = "standard"
    network = data.terraform_remote_state.gke.outputs.vpc_name
  }
}
