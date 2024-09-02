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
        name = "mygateway1-regional"
        sectionName = "https"
      }]
      rules = [
        # Rule-1: App1
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/app1"
              }
            }
          ]
          backendRefs = [
            {
              name = kubernetes_service_v1.myapp1_service.metadata[0].name 
              port = 80
            }
          ]
        },
        # Rule-2: App2
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/app2"
              }
            }
          ]
          backendRefs = [
            {
              name = kubernetes_service_v1.myapp2_service.metadata[0].name 
              port = 80
            }
          ]
        },
        # Rule-3: App3 (Default App)
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

