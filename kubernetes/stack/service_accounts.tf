resource "kubernetes_service_account_v1" "this" {
  for_each = var.service_accounts

  metadata {
    namespace   = var.namespace
    name        = each.key
    annotations = each.value.annotations
  }
}
