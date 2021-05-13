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
  type = map(any)
}

variable "web_services" {
  type = set(string)
}

variable "secrets" {
  type = map(map(any))
}

variable "ingresses" {
  type = map(any)
}
