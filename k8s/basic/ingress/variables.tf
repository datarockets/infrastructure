variable "app" {
  type = string
}

variable "name" {
  type = string
}

variable "ingress" {
  type = object({
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
