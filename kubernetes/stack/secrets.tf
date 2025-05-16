resource "kubernetes_secret_v1" "this" {
  for_each = var.secrets

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      stack = var.name
    }
  }

  data = each.value
}

data "kubernetes_secret_v1" "external" {
  for_each = local.external_secret_names

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      stack = var.name
    }
  }
}
