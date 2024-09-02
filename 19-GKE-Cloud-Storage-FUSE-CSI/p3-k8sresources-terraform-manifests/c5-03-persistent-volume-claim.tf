# Resource: Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "gcs_fuse_csi_static_pvc" {
  metadata {
    name      = "${local.name}-gcs-fuse-csi-static-pvc"
    namespace = kubernetes_namespace.myns.metadata[0].name 
  }
  spec {
    access_modes = ["ReadWriteMany"]
    volume_name       = kubernetes_persistent_volume.gcs_fuse_csi_pv.metadata[0].name
    storage_class_name = "dummy-storage-class"
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

# Outputs
output "my_pvc" {
  value =  kubernetes_persistent_volume_claim.gcs_fuse_csi_static_pvc.metadata[0].name
}

# NEED FOR PVC
# 1. Dynamic volume provisioning allows storage volumes to be created 
# on-demand. 

# 2. Without dynamic provisioning, cluster administrators have to manually 
# make calls to their cloud or storage provider to create new storage 
# volumes, and then create PersistentVolume objects to represent them in k8s

# 3. The dynamic provisioning feature eliminates the need for cluster 
# administrators to pre-provision storage. Instead, it automatically 
# provisions storage when it is requested by users.

# 4. PVC: Users request dynamically provisioned storage by including 
# a storage class in their PersistentVolumeClaim



