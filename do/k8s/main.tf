# setup token via DIGITALOCEAN_TOKEN env variable

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.29.0"
    }
  }
}

resource "digitalocean_vpc" "vpc" {
  name   = var.project
  region = var.region
}

data "digitalocean_kubernetes_versions" "k8s_versions" {}
resource "digitalocean_kubernetes_cluster" "k8s_cluster" {
  name         = var.project
  region       = var.region
  auto_upgrade = true
  version      = data.digitalocean_kubernetes_versions.k8s_versions.latest_version
  vpc_uuid     = digitalocean_vpc.vpc.id

  node_pool {
    name       = "default-pool"
    size       = var.k8s.node_size
    node_count = var.k8s.node_count
    auto_scale = var.k8s.min_nodes != null && var.k8s.max_nodes != null
    min_nodes  = var.k8s.min_nodes
    max_nodes  = var.k8s.max_nodes
  }
}

resource "digitalocean_container_registry" "container_registry" {
  name                   = var.registry
  subscription_tier_slug = var.container_registry_plan
}

resource "digitalocean_container_registry_docker_credentials" "dcr_credentials_k8s" {
  registry_name = digitalocean_container_registry.container_registry.name
}

resource "digitalocean_container_registry_docker_credentials" "dcr_credentials_cicd" {
  registry_name = digitalocean_container_registry.container_registry.name
  write         = true
}
