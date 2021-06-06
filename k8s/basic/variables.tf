variable "create_app_namespace" {
  type = bool
  default = true
}

variable "app_namespace" {
  type = string
  default = "default"
}

variable "app" {
  type = string
}

variable "email" {
  type = string
}

variable "dcr_credentials" {
  type = string
  default = ""
}

variable "services" {
  type = map(
    object({
      deployment_labels = optional(map(string))
      service_labels = optional(map(string))
      pod_labels = optional(map(string))
      service_account = optional(string)
      replicas = number
      image = string
      ports = list(number)
      env_from_secrets = optional(list(string))
      env_from_field = optional(map(string))
      env = optional(map(string))
      init_container = optional(object({
        image = optional(string)
        command = list(string)
        env_from_secrets = optional(list(string))
        env_from_field = optional(map(string))
        env = optional(map(string))
      }))
    })
  )
  default = {}
}

variable "web_services" {
  type = set(string)
}

variable "secrets" {
  type = map(map(any))
  default = {}
}

variable "ingresses" {
  type = map(
    object({
      disable_tls = optional(bool)
      annotations = map(any)
      rules = list(object({
        host = string
        paths = list(object({
          path = string
          service = optional(string)
          port = optional(number)
        }))
      }))
    })
  )
  default = {}
}

variable "nginx_ingress_helm_chart_options" {
  type = list(object({
    name = string
    value = string
  }))

  default = []
}
