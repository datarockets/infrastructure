resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  chart      = "cert-manager"
  version    = "1.3.1"
  repository = "https://charts.jetstack.io"
  namespace  = kubernetes_namespace.cert-manager.id

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "nginx-ingress" {
  name       = "nginx-ingress"
  chart      = "nginx-ingress"
  version    = "0.9.1"
  repository = "https://helm.nginx.com/stable"
  namespace  = "kube-system"
}
