resource "kubernetes_deployment_v1" "this" {
  for_each = { for k, v in var.components : k => v if v.kind == "deployment" }

  metadata {
    name = each.key
    labels = merge(
      {
        stack     = var.name
        component = each.key
      },
      each.value.deployment.labels,
    )
    namespace = var.namespace
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        stack     = var.name
        component = each.key
      }
    }

    template {
      metadata {
        namespace = var.namespace
        labels = merge(
          {
            stack     = var.name
            component = each.key
          },
          each.value.pod.labels
        )
      }
      spec {
        service_account_name             = each.value.service_account != null ? kubernetes_service_account_v1.this[each.value.service_account].metadata[0].name : "default"
        termination_grace_period_seconds = each.value.pod.termination_grace_period_seconds

        container {
          name    = "main"
          image   = each.value.image
          command = each.value.command

          resources {
            requests = each.value.resources.requests
            limits   = each.value.resources.limits
          }

          dynamic "port" {
            for_each = each.value.ports
            content {
              container_port = port.value
            }
          }

          dynamic "env" {
            for_each = each.value.env.values
            content {
              name  = env.key
              value = env.value
            }
          }

          dynamic "env" {
            for_each = each.value.env.from_field
            content {
              name = env.key
              value_from {
                field_ref {
                  field_path = env.value
                }
              }
            }
          }

          dynamic "env_from" {
            for_each = each.value.env.from_secrets
            content {
              secret_ref {
                name = (
                  contains(local.stack_secret_names, env_from.value)
                  ? kubernetes_secret_v1.this[env_from.value].metadata[0].name
                  : data.kubernetes_secret_v1.external[env_from.value].metadata[0].name
                )
              }
            }
          }

          dynamic "env_from" {
            for_each = each.value.env.from_config_maps
            content {
              config_map_ref {
                name = (
                  contains(local.stack_config_map_names, env_from.value)
                  ? kubernetes_config_map_v1.this[env_from.value].metadata[0].name
                  : data.kubernetes_config_map_v1.external[env_from.value].metadata[0].name
                )
              }
            }
          }

          dynamic "volume_mount" {
            for_each = toset([for mount in each.value.mounts : mount if mount.config_map != null])

            content {
              name       = "config-map-volume-${volume_mount.value.config_map}"
              mount_path = volume_mount.value.path
            }
          }

          dynamic "volume_mount" {
            for_each = toset([for mount in each.value.mounts : mount if mount.secret != null])

            content {
              name       = "secret-volume-${volume_mount.value.secret}"
              mount_path = volume_mount.value.path
            }
          }

          dynamic "startup_probe" {
            for_each = each.value.startup_probe != null ? [each.value.startup_probe] : []
            content {
              initial_delay_seconds = startup_probe.value.initial_delay_seconds
              period_seconds        = startup_probe.value.period_seconds
              timeout_seconds       = startup_probe.value.timeout_seconds
              success_threshold     = startup_probe.value.success_threshold
              failure_threshold     = startup_probe.value.failure_threshold

              dynamic "http_get" {
                for_each = startup_probe.value.http_get != null ? [startup_probe.value.http_get] : []
                content {
                  path = http_get.value.path
                  port = http_get.value.port

                  dynamic "http_header" {
                    for_each = http_get.value.http_headers
                    content {
                      name  = http_header.key
                      value = http_header.value
                    }
                  }
                }
              }

              dynamic "exec" {
                for_each = startup_probe.value.exec != null ? [startup_probe.value.exec] : []
                content {
                  command = exec.value.command
                }
              }
            }
          }

          dynamic "readiness_probe" {
            for_each = each.value.readiness_probe != null ? [each.value.readiness_probe] : []
            content {
              initial_delay_seconds = readiness_probe.value.initial_delay_seconds
              period_seconds        = readiness_probe.value.period_seconds
              timeout_seconds       = readiness_probe.value.timeout_seconds
              success_threshold     = readiness_probe.value.success_threshold
              failure_threshold     = readiness_probe.value.failure_threshold

              dynamic "http_get" {
                for_each = readiness_probe.value.http_get != null ? [readiness_probe.value.http_get] : []
                content {
                  path = http_get.value.path
                  port = http_get.value.port

                  dynamic "http_header" {
                    for_each = http_get.value.http_headers
                    content {
                      name  = http_header.key
                      value = http_header.value
                    }
                  }
                }
              }

              dynamic "exec" {
                for_each = readiness_probe.value.exec != null ? [readiness_probe.value.exec] : []
                content {
                  command = exec.value.command
                }
              }
            }
          }

          dynamic "liveness_probe" {
            for_each = each.value.liveness_probe != null ? [each.value.liveness_probe] : []
            content {
              initial_delay_seconds = liveness_probe.value.initial_delay_seconds
              period_seconds        = liveness_probe.value.period_seconds
              timeout_seconds       = liveness_probe.value.timeout_seconds
              success_threshold     = liveness_probe.value.success_threshold
              failure_threshold     = liveness_probe.value.failure_threshold

              dynamic "http_get" {
                for_each = liveness_probe.value.http_get != null ? [liveness_probe.value.http_get] : []
                content {
                  path = http_get.value.path
                  port = http_get.value.port

                  dynamic "http_header" {
                    for_each = http_get.value.http_headers
                    content {
                      name  = http_header.key
                      value = http_header.value
                    }
                  }
                }
              }

              dynamic "exec" {
                for_each = liveness_probe.value.exec != null ? [liveness_probe.value.exec] : []
                content {
                  command = exec.value.command
                }
              }
            }
          }
        }

        dynamic "init_container" {
          for_each = (
            each.value.init_container.image != null || each.value.init_container.command != null
            ? [each.value.init_container] : []
          )

          content {
            name    = "init"
            image   = coalesce(init_container.value.image, each.value.image)
            command = init_container.value.command

            dynamic "env" {
              for_each = (
                coalesce(init_container.value.image, each.value.image) == each.value.image
                ? merge(
                  coalesce(init_container.value.env.values, each.value.env.values),
                  init_container.value.env.values_override,
                )
                : coalesce(init_container.value.env.values, {})
              )
              content {
                name  = env.key
                value = env.value
              }
            }

            dynamic "env" {
              for_each = (
                coalesce(init_container.value.image, each.value.image) == each.value.image
                ? merge(
                  coalesce(init_container.value.env.from_field, each.value.env.from_field),
                  init_container.value.env.from_field_override,
                )
                : coalesce(init_container.value.env.from_field, {})
              )
              content {
                name = env.key
                value_from {
                  field_ref {
                    field_path = env.value
                  }
                }
              }
            }

            dynamic "env_from" {
              for_each = (
                coalesce(init_container.value.image, each.value.image) == each.value.image
                ? coalesce(init_container.value.env.from_secrets, each.value.env.from_secrets)
                : init_container.value.env.from_secrets
              )
              content {
                secret_ref {
                  name = (
                    contains(local.stack_secret_names, env_from.value)
                    ? kubernetes_secret_v1.this[env_from.value].metadata[0].name
                    : data.kubernetes_secret_v1.external[env_from.value].metadata[0].name
                  )
                }
              }
            }

            dynamic "env_from" {
              for_each = (
                coalesce(init_container.value.image, each.value.image) == each.value.image
                ? coalesce(init_container.value.env.from_config_maps, each.value.env.from_config_maps)
                : init_container.value.env.from_config_maps
              )
              content {
                config_map_ref {
                  name = (
                    contains(local.stack_config_map_names, env_from.value)
                    ? kubernetes_config_map_v1.this[env_from.value].metadata[0].name
                    : data.kubernetes_config_map_v1.external[env_from.value].metadata[0].name
                  )
                }
              }
            }

            dynamic "volume_mount" {
              for_each = [
                for mount in(
                  coalesce(init_container.value.image, each.value.image) == each.value.image
                  ? coalesce(init_container.value.mounts, each.value.mounts)
                  : coalesce(init_container.value.mounts, [])
                )
                : mount if mount.config_map != null
              ]

              content {
                name       = "config-map-volume-${volume_mount.value.config_map}"
                mount_path = volume_mount.value.path
              }
            }

            dynamic "volume_mount" {
              for_each = [
                for mount in(
                  coalesce(init_container.value.image, each.value.image) == each.value.image
                  ? coalesce(init_container.value.mounts, each.value.mounts)
                  : coalesce(init_container.value.mounts, [])
                )
                : mount if mount.secret != null
              ]

              content {
                name       = "secret-volume-${volume_mount.value.secret}"
                mount_path = volume_mount.value.path
              }
            }
          }
        }

        dynamic "volume" {
          for_each = toset(flatten([
            [for mount in each.value.mounts : mount if mount.config_map != null],
            [for mount in coalesce(each.value.init_container.mounts, []) : mount if mount.config_map != null],
          ]))

          content {
            name = "config-map-volume-${volume.value.config_map}"

            config_map {
              name = (
                contains(local.stack_config_map_names, volume.value.config_map)
                ? kubernetes_config_map_v1.this[volume.value.config_map].metadata[0].name
                : data.kubernetes_config_map_v1.external[volume.value.config_map].metadata[0].name
              )

              dynamic "items" {
                for_each = coalesce(volume.value.items, {})
                content {
                  key  = items.key
                  path = items.value.path
                  mode = items.value.mode
                }
              }
            }
          }
        }

        dynamic "volume" {
          for_each = toset(flatten([
            [for mount in each.value.mounts : mount if mount.secret != null],
            [for mount in coalesce(each.value.init_container.mounts, []) : mount if mount.secret != null],
          ]))

          content {
            name = "secret-volume-${volume.value.secret}"

            secret {
              secret_name = (
                contains(local.stack_secret_names, volume.value.secret)
                ? kubernetes_secret_v1.this[volume.value.secret].metadata[0].name
                : data.kubernetes_secret_v1.external[volume.value.secret].metadata[0].name
              )

              dynamic "items" {
                for_each = coalesce(volume.value.items, {})
                content {
                  key  = items.key
                  path = items.value.path
                  mode = items.value.mode
                }
              }
            }
          }
        }
      }
    }
  }
}

