resource "kubernetes_manifest" "http_to_https_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "HTTPRoute"
    metadata = {
      name = "redirect"
      namespace = "default"         
    }
    spec = {
      parentRefs = [
        {
          name        = "mygateway1-regional"
          sectionName = "http"
        }
      ]
      rules = [
        {
          filters = [
            {
              type           = "RequestRedirect"
              requestRedirect = {
              scheme = "https"
              }
            }
          ]
        }
      ]
    }
  }
}
