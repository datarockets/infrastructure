variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "db_cluster" {
  type = object({
    version    = string
    size       = string
    node_count = number
  })
  default = {
    version    = "12"
    size       = "db-s-1vcpu-1gb"
    node_count = 1
  }
}

variable "database" {
  type = object({
    name     = string
    username = string
  })
}
