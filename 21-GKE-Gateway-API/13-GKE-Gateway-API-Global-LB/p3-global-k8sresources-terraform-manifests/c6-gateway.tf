resource "kubernetes_manifest" "my_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name = "mygateway1-global"
      namespace = "default"
    }
    spec = {
      gatewayClassName = "gke-l7-global-external-managed"
      listeners = [{
        name     = "http"
        protocol = "HTTP"
        port     = 80
      }]
    }
  }
}
