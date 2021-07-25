variable "app_namespace" {
  type = string
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
      mount_secrets = optional(map(string))
      init_container = optional(object({
        image = optional(string)
        command = list(string)
        env_from_secrets = optional(list(string))
        env_from_field = optional(map(string))
        env = optional(map(string))
        mount_secrets = optional(map(string))
      }))
    })
  )
}

variable "web_services" {
  type = set(string)
}

variable "secrets" {
  type = map(map(any))
}

variable "service_accounts" {
  type = map(object({
    annotations = map(string)
  }))
  default = {}
}
