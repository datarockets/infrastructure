terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.1"
    }

    kubernetes-alpha = {
      source = "hashicorp/kubernetes-alpha"
      version = "~> 0.3.2"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.1"
    }
  }
  experiments = [module_variable_optional_attrs]
}

resource "kubernetes_namespace" "application" {
  metadata {
    name = var.app
  }
}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_secret" "secret" {
  for_each = var.secrets

  metadata {
    name = each.key
    namespace = kubernetes_namespace.application.id
  }

  data = each.value
}

resource "kubernetes_secret" "docker-config" {
  metadata {
    name = "docker-config"
    namespace = kubernetes_namespace.application.id
  }

  data = {
    ".dockerconfigjson" = var.dcr_credentials
  }
  type = "kubernetes.io/dockerconfigjson"
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

resource "kubernetes_deployment" "deployment" {
  for_each = var.services

  metadata {
    name = each.key
    labels = merge(
      {
        app = var.app
        service = each.key
      },
      each.value.deployment_labels != null ? each.value.deployment_labels : {}
    )
    namespace = kubernetes_namespace.application.id
  }

  spec {
    replicas = each.value.replicas
    selector {
      match_labels = {
        service = each.key
      }
    }
    template {
      metadata {
        labels = merge(
          {
            app = var.app
            service = each.key
          },
          each.value.pod_labels != null ? each.value.pod_labels : {}
        )
        namespace = kubernetes_namespace.application.id
      }
      spec {
        image_pull_secrets {
          name = kubernetes_secret.docker-config.metadata[0].name
        }
        container {
          name = each.key
          image = each.value.image

          dynamic "port" {
            for_each = each.value.ports
            content {
              container_port = port.value
            }
          }

          dynamic "env_from" {
            for_each = each.value.env_from_secrets != null ? each.value.env_from_secrets : []
            content {
              secret_ref {
                name = kubernetes_secret.secret[env_from.value].metadata[0].name
                optional = false
              }
            }
          }

          dynamic "env" {
            for_each = each.value.env != null ? each.value.env : {}
            content {
              name = env.key
              value = env.value
            }
          }
        }

        dynamic "init_container" {
          for_each = each.value.init_command != null ? {(each.key) = each.value} : {}

          content {
            name = "${each.key}-init-container"
            image = each.value.image
            command = each.value.init_command

            dynamic "env_from" {
              for_each = each.value.env_from_secrets != null ? each.value.env_from_secrets : []
              content {
                secret_ref {
                  name = kubernetes_secret.secret[env_from.value].metadata[0].name
                  optional = false
                }
              }
            }

            dynamic "env" {
              for_each = each.value.env != null ? each.value.env : {}
              content {
                name = env.key
                value = env.value
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "service" {
  for_each = var.web_services

  metadata {
    name = each.key
    labels = merge(
      {
        app = var.app
        service = each.key
      },
      var.services[each.key].service_labels != null ? var.services[each.key].service_labels : {}
    )
    namespace = kubernetes_namespace.application.id
  }
  spec {
    type = "ClusterIP"
    selector = kubernetes_deployment.deployment[each.key].metadata[0].labels

    dynamic "port" {
      for_each = var.services[each.key].ports
      content {
        port = port.value
        target_port = port.value
      }
    }
  }
}

resource "kubernetes_manifest" "cert-issuer-letsencrypt" {
  provider = kubernetes-alpha

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = "letsencrypt"
      namespace = kubernetes_namespace.application.id
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.email
        privateKeySecretRef = {
          name = "letsencrypt-issuer-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = "nginx"
            }
          }
        }]
      }
    }
  }
}

resource "helm_release" "nginx-ingress" {
  name       = "nginx-ingress"
  chart      = "nginx-ingress"
  version    = "0.9.1"
  repository = "https://helm.nginx.com/stable"
  namespace  = "kube-system"
}

resource "kubernetes_ingress" "ingress" {
  for_each = var.ingresses
  metadata {
    name = each.key
    namespace = kubernetes_namespace.application.id
    annotations = merge(
      {
        "cert-manager.io/issuer" = "letsencrypt"
      },
      each.value.annotations
    )
  }
  wait_for_load_balancer = true
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = each.value.rules[*].host
      secret_name = "letsencrypt-tls-${each.key}"
    }
    dynamic "rule" {
      for_each = each.value.rules
      content {
        host = rule.value.host
        http {
          dynamic "path" {
            for_each = rule.value.paths
            content {
              path = path.value.path
              backend {
                service_name = kubernetes_service.service[path.value.service].metadata[0].name
                service_port = path.value.port
              }
            }
          }
        }
      }
    }
  }
}
