terraform {
  experiments = [module_variable_optional_attrs]
}

resource "kubernetes_ingress" "ingress" {
  metadata {
    name = var.name
    namespace = var.app
    annotations = merge(
      var.ingress.disable_tls == true ? {} : {"cert-manager.io/issuer" = "letsencrypt"},
      var.ingress.annotations
    )
    labels = {
      app = var.app
    }
  }
  wait_for_load_balancer = true
  spec {
    ingress_class_name = "nginx"
    dynamic "tls" {
      for_each = var.ingress.disable_tls == true ? [] : toset(["enable"])

      content {
        hosts = var.ingress.rules[*].host
        secret_name = "letsencrypt-tls-${var.name}"
      }
    }
    dynamic "rule" {
      for_each = var.ingress.rules
      content {
        host = rule.value.host
        http {
          dynamic "path" {
            for_each = rule.value.paths
            content {
              path = path.value.path
              backend {
                service_name = path.value.service
                service_port = path.value.port
              }
            }
          }
        }
      }
    }
  }
}
