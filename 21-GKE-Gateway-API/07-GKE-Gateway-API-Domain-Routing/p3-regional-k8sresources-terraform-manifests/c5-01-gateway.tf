resource "kubernetes_manifest" "my_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name = "mygateway1-regional"
      namespace = "default"
    }
    spec = {
      gatewayClassName = "gke-l7-regional-external-managed"
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            kinds = [
              {
                kind = "HTTPRoute"
              }
            ]
            namespaces = {
              from = "Same"
            }
          }
        },     
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          allowedRoutes = {
            kinds = [
              {
                kind = "HTTPRoute"
              }
            ]
            namespaces = {
              from = "All"
            }
          }
          tls = {
            mode = "Terminate"
            options = {
              "networking.gke.io/cert-manager-certs" = google_certificate_manager_certificate.app1_cert.name
            }
          }
        }
      ]
      addresses = [{
        type  = "NamedAddress"
        value = google_compute_address.static_ip.name
      }]        
    }
  }
}
