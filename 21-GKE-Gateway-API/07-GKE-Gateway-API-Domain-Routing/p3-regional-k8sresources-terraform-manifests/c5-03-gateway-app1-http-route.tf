resource "kubernetes_manifest" "app1_http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = "app1-route"
      namespace = "default"      
    }
    spec = {
      parentRefs = [{
        kind = "Gateway"
        name = "mygateway1-regional"
        sectionName = "https"
      }]
      hostnames = ["app1.stacksimplify.com"]      
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
        }
      ]      
    }
  }
}

