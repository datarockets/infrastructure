resource "kubernetes_config_map_v1" "this" {
  for_each = var.config_maps

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      stack = var.name
    }
  }

  data = each.value
}

data "kubernetes_config_map_v1" "external" {
  for_each = local.external_config_map_names

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      stack = var.name
    }
  }
}
