resource "kubernetes_manifest" "http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = "route-external-http"
      namespace = "default"      
    }
    spec = {
      parentRefs = [{
        kind = "Gateway"
        name = "mygateway1-global"
      }]
      rules = [{
        backendRefs = [{
          name = kubernetes_service_v1.service.metadata[0].name 
          port = 80
        }]
      }]
    }
  }
}
