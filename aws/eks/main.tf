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
