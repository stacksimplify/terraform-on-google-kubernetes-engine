resource "kubernetes_secret" "tls_secret" {
  metadata {
    name = "${local.name}-my-tls-secret"
    namespace = "default" 
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = file("${path.module}/self-signed-ssl/app1.crt")
    "tls.key" = file("${path.module}/self-signed-ssl/app1.key")
  }
}

output "tls_secret_name" {
  value = kubernetes_secret.tls_secret.metadata[0].name
}
