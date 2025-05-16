variable "cert_manager" {
  type = object({
    enabled           = optional(bool, true)
    version           = optional(string, "1.17.2")
    namespace         = optional(string, "system-cert-manager")
    create_namespace  = optional(bool, true)
    helm_chart_values = optional(map(string), {})

    aws = optional(object({
      # This is useful when you use DNS resolver
      # It's a convenient shortcut to passing values manually
      service_account_iam_role_arn = optional(string)
    }), {})
  })
  default = {}
}

resource "helm_release" "cert_manager" {
  count = var.cert_manager.enabled ? 1 : 0

  repository = "https://charts.jetstack.io"
  name       = "cert-manager"
  chart      = "cert-manager"
  version    = var.cert_manager.version

  namespace        = var.cert_manager.namespace
  create_namespace = var.cert_manager.create_namespace

  values = [
    yamlencode(
      {
        crds = {
          enabled = true
        }
      },
    ),
    yamlencode(
      var.cert_manager.aws.service_account_iam_role_arn != null ? {
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = var.cert_manager.aws.service_account_iam_role_arn
          }
        }
      } : {}
    ),
    yamlencode(var.cert_manager.helm_chart_values),
  ]
}
