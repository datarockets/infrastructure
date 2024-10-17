variable "nginx_ingress_helm_chart_options" {
  type = list(object({
    name = string
    value = string
  }))

  default = []
}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  chart      = "cert-manager"
  version    = "1.16.1"
  repository = "https://charts.jetstack.io"
  namespace  = kubernetes_namespace.cert-manager.id

  set {
    name  = "crds.enabled"
    value = "true"
  }
  set {
    name = "crds.keep"
    value = "true"
  }
}

resource "helm_release" "nginx-ingress" {
  name       = "nginx-ingress"
  chart      = "nginx-ingress"
  version    = "1.4.0"
  repository = "https://helm.nginx.com/stable"
  namespace  = "kube-system"

  set {
    name = "controller.enableSnippets"
    value = true
  }

  dynamic "set" {
    for_each = {for i, param in var.nginx_ingress_helm_chart_options: tostring(i) => param}

    content {
      name = set.value.name
      value = set.value.value
    }
  }
}
