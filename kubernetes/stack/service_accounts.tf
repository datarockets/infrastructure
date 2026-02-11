resource "kubernetes_service_account_v1" "this" {
  for_each = var.service_accounts

  metadata {
    namespace   = var.namespace
    name        = each.key
    annotations = each.value.annotations
  }

  dynamic "image_pull_secret" {
    for_each = each.value.image_pull_secret != null ? [each.value.image_pull_secret] : []
    content {
      name = image_pull_secret.value
    }
  }
}

locals {
  service_account_role_bindings = flatten([
    for sa_name, sa in var.service_accounts : [
      for role in sa.roles : {
        service_account = sa_name
        role            = role
      }
    ]
  ])
}

resource "kubernetes_role_binding_v1" "service_account_role_bindings" {
  for_each = {
    for binding in local.service_account_role_bindings :
    "${binding.service_account}-${binding.role}" => binding
  }

  metadata {
    namespace = var.namespace
    name      = "${each.key}-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.value.role
  }

  subject {
    kind      = "ServiceAccount"
    name      = each.value.service_account
    namespace = var.namespace
  }
}
