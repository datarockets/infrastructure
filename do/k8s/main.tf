# setup token via DIGITALOCEAN_TOKEN env variable

terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.8"
    }
  }
}

resource "digitalocean_vpc" "vpc" {
  name = var.project
  region = var.region
}

data "digitalocean_kubernetes_versions" "k8s_versions" {}
resource "digitalocean_kubernetes_cluster" "k8s_cluster" {
  name = var.project
  region = var.region
  auto_upgrade = true
  version = data.digitalocean_kubernetes_versions.k8s_versions.latest_version
  vpc_uuid = digitalocean_vpc.vpc.id

  node_pool {
    name = "default-pool"
    size = var.k8s.node_size
    node_count = var.k8s.node_count
  }
}

resource "digitalocean_container_registry" "container_registry" {
  name = var.project
  subscription_tier_slug = var.container_registry_plan
}

resource "digitalocean_container_registry_docker_credentials" "dcr_credentials_k8s" {
  registry_name = digitalocean_container_registry.container_registry.name
}

resource "digitalocean_container_registry_docker_credentials" "dcr_credentials_cicd" {
  registry_name = digitalocean_container_registry.container_registry.name
  write = true
}

resource "digitalocean_database_cluster" "main" {
  name = var.project
  region = var.region
  engine = "pg"
  version = var.db_cluster.version
  node_count = var.db_cluster.node_count
  size = var.db_cluster.size
  private_network_uuid = digitalocean_vpc.vpc.id
}

resource "digitalocean_database_db" "database" {
  cluster_id = digitalocean_database_cluster.main.id
  name = var.database.name
}

resource "digitalocean_database_user" "db_user" {
  cluster_id = digitalocean_database_cluster.main.id
  name = var.database.username
}

resource "digitalocean_database_firewall" "db_firewall" {
  cluster_id = digitalocean_database_cluster.main.id

  rule {
    type = "k8s"
    value = digitalocean_kubernetes_cluster.k8s_cluster.id
  }
}
