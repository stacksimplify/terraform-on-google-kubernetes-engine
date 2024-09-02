resource "kubernetes_manifest" "app3_http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = "app3-default-route"
      namespace = "default"      
    }
    spec = {
      parentRefs = [{
        kind = "Gateway"
        name = "mygateway1-regional"
        sectionName = "https"
      }]
      rules = [
        # Rule-3: App3 - Default Route
        {
          backendRefs = [
            {
              name = kubernetes_service_v1.myapp3_service.metadata[0].name 
              port = 80
            }
          ]
        }
      ]      
    }
  }
}

