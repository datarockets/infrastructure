variable "app_namespace" {
  type = string
}

variable "app" {
  type = string
}

variable "name" {
  type = string
}

variable "ingress" {
  type = object({
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
}
