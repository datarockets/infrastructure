terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.1"
    }

    kubernetes-alpha = {
      source = "hashicorp/kubernetes-alpha"
      version = "~> 0.3.2"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.1"
    }
  }
}

module "dependencies" {
  source = "./dependencies"
  nginx_ingress_helm_chart_options = var.nginx_ingress_helm_chart_options
}

module "cluster" {
  depends_on = [
    module.dependencies
  ]

  source = "./cluster"

  app = var.app
  email = var.email
  dcr_credentials = var.dcr_credentials
  services = var.services
  web_services = var.web_services
  secrets = var.secrets
}

module "ingress" {
  for_each = var.ingresses

  depends_on = [
    module.cluster
  ]

  source = "./ingress"

  app = var.app
  name = each.key
  ingress = each.value
}
