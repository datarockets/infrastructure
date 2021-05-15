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
  type = map(any)
}

variable "web_services" {
  type = set(string)
}

variable "secrets" {
  type = map(map(any))
  default = {}
}

variable "ingresses" {
  type = map(any)
  default = {}
}

variable "nginx_ingress_helm_chart_options" {
  type = list(object({
    name = string
    value = string
  }))

  default = []
}
