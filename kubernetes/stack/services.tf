resource "kubernetes_service_v1" "this" {
  for_each = {
    for name, componenet in var.components :
    name => componenet if componenet.service.enabled
  }

  metadata {
    name      = each.key
    namespace = var.namespace

    annotations = each.value.service.annotations
    labels = merge(
      {
        stack     = var.name
        component = each.key
      },
      each.value.service.labels,
    )
  }

  spec {
    type     = "ClusterIP"
    selector = kubernetes_deployment_v1.this[each.key].metadata[0].labels

    dynamic "port" {
      for_each = toset(each.value.ports)

      content {
        port        = port.value
        target_port = port.value
      }
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations["cloud.google.com/neg"]]
  }
}
