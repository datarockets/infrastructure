terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.7.1"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.4.1"
    }
  }
  experiments = [module_variable_optional_attrs]
}

module "dependencies" {
  source = "./dependencies"
  nginx_ingress_helm_chart_options = var.nginx_ingress_helm_chart_options
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app
  }
}

module "cluster" {
  depends_on = [
    module.dependencies
  ]

  source = "./cluster"

  app_namespace = kubernetes_namespace.app.id

  app = var.app
  email = var.email
  dcr_credentials = var.dcr_credentials
  service_accounts = var.service_accounts
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

  app_namespace = kubernetes_namespace.app.id

  app = var.app
  name = each.key
  ingress = each.value
}
