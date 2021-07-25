terraform {
  experiments = [module_variable_optional_attrs]
}

resource "kubernetes_secret" "secret" {
  for_each = var.secrets

  metadata {
    name = each.key
    namespace = var.app_namespace
  }

  data = each.value
}

resource "kubernetes_secret" "docker-config" {
  for_each = var.dcr_credentials != "" ? { default = var.dcr_credentials } : {}

  metadata {
    name = "docker-config"
    namespace = var.app_namespace
  }

  data = {
    ".dockerconfigjson" = each.value
  }
  type = "kubernetes.io/dockerconfigjson"
}

locals {
  service_account_names_from_services = [for name, service in var.services: service.service_account]
  service_account_names = compact(
    distinct(
      concat(
        keys(var.service_accounts),
        local.service_account_names_from_services
      )
    )
  )
}

resource "kubernetes_service_account" "service_account" {
  for_each = toset(local.service_account_names)

  metadata {
    namespace = var.app_namespace
    name = each.value
    annotations = lookup(
      lookup(var.service_accounts, each.value, {annotations = {}}),
      "annotations",
      null
    )
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
    namespace = var.app_namespace
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
        namespace = var.app_namespace
      }
      spec {
        service_account_name = each.value.service_account != null ? kubernetes_service_account.service_account[each.value.service_account].metadata[0].name : "default"

        dynamic "image_pull_secrets" {
          for_each = var.dcr_credentials != "" ? { default = var.dcr_credentials } : {}
          content {
            name = kubernetes_secret.docker-config[image_pull_secrets.key].metadata[0].name
          }
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

          dynamic "env" {
            for_each = each.value.env_from_field != null ? each.value.env_from_field : {}
            content {
              name = env.key
              value_from {
                field_ref {
                  field_path = env.value
                }
              }
            }
          }

          dynamic "volume_mount" {
            for_each = each.value.mount_secrets
            content {
              name = volume_mount.key
              mount_path = volume_mount.value
            }
          }
        }

        dynamic "init_container" {
          for_each = each.value.init_container != null ? [each.value.init_container] : []

          content {
            name = "${each.key}-init-container"
            image = init_container.value.image != null ? init_container.value.image : each.value.image
            command = init_container.value.command

            dynamic "env_from" {
              for_each = init_container.value.env_from_secrets != null ? init_container.value.env_from_secrets : []
              content {
                secret_ref {
                  name = kubernetes_secret.secret[env_from.value].metadata[0].name
                  optional = false
                }
              }
            }

            dynamic "env" {
              for_each = init_container.value.env != null ? init_container.value.env : {}
              content {
                name = env.key
                value = env.value
              }
            }

            dynamic "env" {
              for_each = init_container.value.env_from_field != null ? each.value.env_from_field : {}
              content {
                name = env.key
                value_from {
                  field_ref {
                    field_path = env.value
                  }
                }
              }
            }

            dynamic "volume_mount" {
              for_each = init_container.value.mount_secrets
              content {
                name = volume_mount.key
                mount_path = volume_mount.value
              }
            }
          }
        }

        dynamic "volume" {
          for_each = each.value.mount_secrets

          content {
            name = volume.key
            secret {
              secret_name = volume.key
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
    namespace = var.app_namespace
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
      namespace = var.app_namespace
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
