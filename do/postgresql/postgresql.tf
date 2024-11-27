terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.17.0"
    }
  }
}

data "digitalocean_vpc" "vpc" {
  name = var.project
}

data "digitalocean_kubernetes_cluster" "k8s_cluster" {
  name = var.project
}

resource "digitalocean_database_cluster" "main" {
  name                 = var.project
  region               = var.region
  engine               = "pg"
  version              = var.db_cluster.version
  node_count           = var.db_cluster.node_count
  size                 = var.db_cluster.size
  private_network_uuid = data.digitalocean_vpc.vpc.id
}

resource "digitalocean_database_db" "database" {
  cluster_id = digitalocean_database_cluster.main.id
  name       = var.database.name
}

resource "digitalocean_database_user" "db_user" {
  cluster_id = digitalocean_database_cluster.main.id
  name       = var.database.username
}

resource "digitalocean_database_firewall" "db_firewall" {
  cluster_id = digitalocean_database_cluster.main.id

  rule {
    type  = "k8s"
    value = data.digitalocean_kubernetes_cluster.k8s_cluster.id
  }
}
