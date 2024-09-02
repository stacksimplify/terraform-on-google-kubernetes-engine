# Resource: UserMgmt WebApp Kubernetes Deployment
resource "kubernetes_deployment_v1" "usermgmt_webapp" {
  metadata {
    name = "usermgmt-webapp"
    labels = {
      app = "usermgmt-webapp"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "usermgmt-webapp"
      }
    }
    template {
      metadata {
        labels = {
          app = "usermgmt-webapp"
        }
      }
      spec {
        container {
          image = "ghcr.io/stacksimplify/kube-usermgmt-webapp:1.0.0-MySQLDB"
          name  = "usermgmt-webapp"
          #image_pull_policy = "always"  # Defaults to Always so we can comment this
          port {
            container_port = 8080
          }
          env {
            name = "DB_HOSTNAME"
            value = data.terraform_remote_state.cloudsql.outputs.cloudsql_db_private_ip
          }
          env {
            name = "DB_PORT"
            value = "3306"
          }
          env {
            name = "DB_NAME"
            value = data.terraform_remote_state.cloudsql.outputs.mydb_schema
          }
          env {
            name = "DB_USERNAME"
            value = data.terraform_remote_state.cloudsql.outputs.mydb_user
          }
          env {
            name = "DB_PASSWORD"
            value = data.terraform_remote_state.cloudsql.outputs.mydb_password
          }          
        }
      }
    }
  }
}
