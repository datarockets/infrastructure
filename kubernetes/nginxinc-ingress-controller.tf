variable "nginxinc_ingress_controller" {
  type = object({
    enabled           = optional(bool, true)
    version           = optional(string, "2.1.0")
    namespace         = optional(string, "system-nic")
    create_namespace  = optional(bool, true)
    helm_chart_values = optional(map(string), {})

    aws = optional(object({
      service_load_balancer_type = optional(string, "nlb")
    }))

    ingress_class_name = optional(string, "nginx")
  })
  default = {}
}

data "kubernetes_nodes" "all" {}

locals {
  is_cluster_on_aws = alltrue([
    for node in data.kubernetes_nodes.all.nodes :
    can(regex("^aws://", node.spec[0].provider_id))
  ])
}

resource "helm_release" "nginxinc_ingress_controller" {
  count = var.nginxinc_ingress_controller.enabled ? 1 : 0

  repository = "https://helm.nginx.com/stable"
  name       = "nginx-ingress"
  chart      = "nginx-ingress"
  version    = var.nginxinc_ingress_controller.version

  namespace        = var.nginxinc_ingress_controller.namespace
  create_namespace = var.nginxinc_ingress_controller.create_namespace

  values = [
    yamlencode(
      {
        controller = {
          kind           = "daemonset"
          enableSnippets = true
          healthStatus   = true
          config = {
            entries = {
              http2 = "true"
            }
          }
          ingressClass = {
            name = var.nginxinc_ingress_controller.ingress_class_name
          }
        }
      },
    ),
    yamlencode(
      var.nginxinc_ingress_controller.aws != null ?
      var.nginxinc_ingress_controller.aws.service_load_balancer_type != null ? {
        controller = {
          service = {
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-type" = var.nginxinc_ingress_controller.aws.service_load_balancer_type
            }
          }
        }
      } : {}
      :
      local.is_cluster_on_aws ? {
        controller = {
          service = {
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            }
          }
        }
      } : {}
    ),
    yamlencode(var.nginxinc_ingress_controller.helm_chart_values),
  ]
}

data "kubernetes_service_v1" "nginxinc_ingress_controller" {
  count = var.nginxinc_ingress_controller.enabled ? 1 : 0

  metadata {
    namespace = helm_release.nginxinc_ingress_controller[0].namespace
    name      = "${helm_release.nginxinc_ingress_controller[0].name}-controller"
  }
  depends_on = [helm_release.nginxinc_ingress_controller[0]]
}
