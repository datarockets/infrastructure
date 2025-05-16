resource "kubernetes_ingress_v1" "this" {
  for_each = var.ingress != null ? { (var.name) = var.ingress } : {}

  metadata {
    name      = each.key
    namespace = var.namespace
    annotations = merge(
      each.value.tls != null ? {
        "cert-manager.io/cluster-issuer"            = each.value.tls.cluster_issuer
        "cert-manager.io/issuer"                    = each.value.tls.issuer
        "acme.cert-manager.io/http01-edit-in-place" = "true"
      } : {},
      each.value.annotations,
    )
    labels = merge(
      { stack = var.name },
      each.value.labels,
    )
  }

  wait_for_load_balancer = true

  spec {
    ingress_class_name = each.value.class

    dynamic "tls" {
      for_each = each.value.tls != null ? [each.value.tls] : []

      content {
        secret_name = coalesce(
          tls.value.secret_name,
          "${each.key}-${coalesce(tls.value.issuer, tls.value.cluster_issuer)}-tls"
        )
        hosts = keys(each.value.hosts)
      }
    }

    dynamic "rule" {
      for_each = each.value.hosts

      content {
        host = rule.key

        http {
          dynamic "path" {
            for_each = rule.value

            content {
              path = path.key

              backend {
                service {
                  name = kubernetes_service_v1.this[path.value.component].metadata[0].name
                  port {
                    number = path.value.port != null ? path.value.port : var.components[path.value.component].ports[0]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
