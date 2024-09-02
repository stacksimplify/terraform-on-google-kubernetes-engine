resource "kubernetes_manifest" "app2_http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = "app2-route"
      namespace = "default"      
    }
    spec = {
      parentRefs = [{
        kind = "Gateway"
        name = "mygateway1-regional"
        sectionName = "https"
      }]
      hostnames = ["app2.stacksimplify.com"]      
      rules = [
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
        }
      ]      
    }
  }
}

