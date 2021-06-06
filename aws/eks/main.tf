terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.1"
    }
  }
}

variable "app" {
  type = string
}

variable "environment" {
  type = string
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app
  }
}

output "app_namespace" {
  value = kubernetes_namespace.app.id
}
