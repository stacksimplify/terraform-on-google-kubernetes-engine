# Resource: Vertical Pod Autoscaler
# We dont have dedicated Kubernetes resource in terraform for VPA
# We will use Resource: kubernetes_manifest
resource "kubernetes_manifest" "myapp1_vpa" {
  manifest = {
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name      = "myapp1-vpa"
      namespace = "default"
    }
    spec = {
      targetRef = {
        kind       = "Deployment"
        name       = kubernetes_deployment_v1.myapp1.metadata[0].name 
        apiVersion = "apps/v1"
      }
      updatePolicy = {
        updateMode = "Auto"
      }
      resourcePolicy = {
        containerPolicies = [
          {
            containerName       = "myapp1-container"
            mode                = "Auto"
            controlledResources = [
              "cpu",
              "memory"
            ]
            minAllowed = {
              cpu    = "25m"
              memory = "50Mi"
            }
            maxAllowed = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }
        ]
      }
    }
  }
}

