variable "name" {
  description = "Used for labels and selectors"
  type        = string
}

variable "namespace" {
  description = "Namespace to deploy resources into"
  type        = string
}

variable "service_accounts" {
  type = map(
    object({
      annotations = optional(map(string), {})
    })
  )
  default = {}
}

variable "components" {
  type = map(
    object({
      kind = optional(string, "deployment")
      deployment = optional(object({
        labels = optional(map(string), {})
      }), {})
      pod = optional(object({
        labels                           = optional(map(string), {})
        termination_grace_period_seconds = optional(number)
      }), {})
      image           = string
      replicas        = optional(number, 1)
      service_account = optional(string)
      command         = optional(list(string))
      ports           = optional(list(number), [])
      service = optional(object({
        enabled     = optional(bool, false)
        annotations = optional(map(string), {})
        labels      = optional(map(string), {})
      }), {})
      env = optional(
        object({
          values = optional(map(string), {})
          secret_refs = optional(map(object({
            name = string,
            key  = string
          })), {})
          config_map_refs = optional(map(object({
            name = string,
            key  = string
          })), {})
          field_refs = optional(map(object({
            api_version = optional(string, "v1"),
            path        = string
          })), {})
          from_field       = optional(map(string), {})
          from_secrets     = optional(set(string), [])
          from_config_maps = optional(set(string), [])
        }),
        {}
      )
      mounts = optional(list(object({
        path       = string
        config_map = optional(string)
        secret     = optional(string)
        items = optional(map(object({
          path = string
          mode = optional(string)
        })))
        default_mode = optional(string)
      })), [])
      resources = optional(object({
        requests = optional(object({
          cpu               = optional(string)
          memory            = optional(string)
          ephemeral-storage = optional(string)
        }), {})
        limits = optional(object({
          cpu               = optional(string)
          memory            = optional(string)
          ephemeral-storage = optional(string)
        }), {})
      }), {})
      init_container = optional(object({
        image   = optional(string)
        command = optional(list(string))
        env = optional(
          object({
            values              = optional(map(string))
            values_override     = optional(map(string), {})
            from_field          = optional(map(string))
            from_field_override = optional(map(string), {})
            from_secrets        = optional(set(string))
            from_config_maps    = optional(set(string))
          }),
          {}
        )
        mounts = optional(list(object({
          path       = string
          config_map = optional(string)
          secret     = optional(string)
          items = optional(map(object({
            path = string
            mode = optional(string)
          })))
          default_mode = optional(string)
        })))
      }), {})
      startup_probe = optional(object({
        initial_delay_seconds = optional(number)
        period_seconds        = optional(number)
        timeout_seconds       = optional(number)
        success_threshold     = optional(number)
        failure_threshold     = optional(number)
        http_get = optional(object({
          path         = string
          port         = number
          http_headers = optional(map(string), {})
        }))
        exec = optional(object({
          command = list(string)
        }))
      }))
      readiness_probe = optional(object({
        initial_delay_seconds = optional(number)
        period_seconds        = optional(number)
        timeout_seconds       = optional(number)
        success_threshold     = optional(number)
        failure_threshold     = optional(number)
        http_get = optional(object({
          path         = string
          port         = number
          http_headers = optional(map(string), {})
        }))
        exec = optional(object({
          command = list(string)
        }))
      }))
      liveness_probe = optional(object({
        initial_delay_seconds = optional(number)
        period_seconds        = optional(number)
        timeout_seconds       = optional(number)
        success_threshold     = optional(number)
        failure_threshold     = optional(number)
        http_get = optional(object({
          path         = string
          port         = number
          http_headers = optional(map(string), {})
        }))
        exec = optional(object({
          command = list(string)
        }))
      }))
    })
  )
}

variable "secrets" {
  type    = map(map(any))
  default = {}
}

variable "config_maps" {
  type    = map(map(any))
  default = {}
}

variable "ingress" {
  type = object({
    annotations = optional(map(string), {})
    labels      = optional(map(string), {})
    tls = optional(object({
      cluster_issuer = optional(string)
      issuer         = optional(string)
      secret_name    = optional(string)
    }))
    class = optional(string, "nginx")
    hosts = optional(
      map(map(object({
        component = string
        port      = optional(number)
      }))),
      {}
    )
  })
  default = null
}
