variable "app" {
  type = string
}

variable "email" {
  type = string
}

variable "dcr_credentials" {
  type = string
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
      env = optional(map(string))
      init_container = optional(object({
        image = optional(string)
        command = list(string)
        env_from_secrets = optional(list(string))
        env = optional(map(string))
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

variable "ingresses" {
  type = map(object({
    annotations = map(any)
    rules = list(object({
      host = string
      paths = list(object({
        path = string
        service = optional(string)
        port = optional(number)
      }))
    }))
  }))
}
