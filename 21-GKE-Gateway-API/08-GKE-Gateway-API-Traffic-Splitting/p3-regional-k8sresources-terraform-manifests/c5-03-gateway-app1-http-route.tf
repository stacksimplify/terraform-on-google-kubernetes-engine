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
      rules = [        
        {
          backendRefs = [
            {
              name = kubernetes_service_v1.myapp1_service_v1.metadata[0].name 
              port = 80
              weight = 50
            },
            {
              name = kubernetes_service_v1.myapp1_service_v2.metadata[0].name 
              port = 80
              weight = 50              
            }            
          ]
        }        
      ]      
    }
  }
}

