variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "registry" {
  type = string
}

variable "k8s" {
  type = object({
    node_size  = string
    node_count = string
  })
  default = {
    node_size  = "s-2vcpu-2gb"
    node_count = 1
  }
}

variable "container_registry_plan" {
  type    = string
  default = "basic"
}
