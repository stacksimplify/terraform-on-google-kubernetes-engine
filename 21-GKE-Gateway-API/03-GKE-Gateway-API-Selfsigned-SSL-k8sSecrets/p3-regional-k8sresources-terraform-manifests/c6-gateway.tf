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
      listeners = [{
        name     = "https"
        protocol = "HTTPS"
        port     = 443
        tls = {
          mode = "Terminate"
          certificateRefs = [{
            name = kubernetes_secret.tls_secret.metadata[0].name
          }]
        }              
      }]
      addresses = [{
        type  = "NamedAddress"
        value = google_compute_address.static_ip.name
      }]        
    }
  }
}
