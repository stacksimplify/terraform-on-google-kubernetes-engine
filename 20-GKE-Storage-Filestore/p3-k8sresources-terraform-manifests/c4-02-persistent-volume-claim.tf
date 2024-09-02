# Resource: Persistent Volume Claim
resource "kubernetes_persistent_volume_claim_v1" "filestore_pvc" {
  metadata {
    name      = "${local.name}-filestore-pvc"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.filestore_sc.metadata[0].name 
    resources {
      requests = {
        storage = "1Ti"
      }
    }
  }
  timeouts {
    create = "20m"
  }
}

# Outputs
output "filestore_pvc" {
  value =  kubernetes_persistent_volume_claim_v1.filestore_pvc.metadata[0].name
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



