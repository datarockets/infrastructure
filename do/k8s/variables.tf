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
    node_count = optional(number)
    min_nodes  = optional(number)
    max_nodes  = optional(number)
  })
  default = {
    node_size  = "s-2vcpu-2gb"
    node_count = 1
  }

  validation {
    condition = (
      (var.k8s.node_count != null && (var.k8s.min_nodes == null && var.k8s.max_nodes == null)) ||
      (var.k8s.node_count == null && (var.k8s.min_nodes != null && var.k8s.max_nodes != null))
    )
    error_message = "You need to indicate either node count or min_nodes with max_nodes for enabling autoscaling, not both options"
  }
}

variable "container_registry_plan" {
  type    = string
  default = "basic"
}
