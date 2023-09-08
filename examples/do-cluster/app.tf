terraform {
  backend "s3" {
    key      = "terraform.tfstate"
    bucket   = "first-project-test"
    region   = "tor1"
    endpoint = "fra1.digitaloceanspaces.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

module "digitalocean" {
  source = "git@github.com:datarockets/infrastructure.git//do/k8s?ref=example-digital-ocean"

  project = "first-project"
  registry = "first-project-test"
  region = "tor1"

  database = {
    name = "example"
    username = "example"
  }
}

provider "kubernetes" {
  host = module.digitalocean.k8s_host
  token = module.digitalocean.k8s_token
  cluster_ca_certificate = module.digitalocean.k8s_ca_certificate
}

provider "kubernetes-alpha" {
  host = module.digitalocean.k8s_host
  token = module.digitalocean.k8s_token
  cluster_ca_certificate = module.digitalocean.k8s_ca_certificate
}

provider "helm" {
  kubernetes {
    host = module.digitalocean.k8s_host
    token = module.digitalocean.k8s_token
    cluster_ca_certificate = module.digitalocean.k8s_ca_certificate
  }
}

module "kubernetes" {
  source = "git@github.com:datarockets/infrastructure.git//k8s/basic?ref=example-digital-ocean"
  depends_on = [
    module.digitalocean
  ]

  app = "example"
  email = "example@datarockets.com"
  dcr_credentials = module.digitalocean.dcr_credentials_k8s
  services = {
    app = {
      replicas = 1
      image = "nginx:latest"
      ports = [80]
      env_from_secrets = ["example"]
    }
  }
  web_services = ["app"]
  # ingresses = {
  #   "example.datarockets.com" = {
  #     annotations = {
  #     }
  #     rules = [
  #       {
  #         host = "example.datarockets.com"
  #         paths = [
  #           {
  #             path = "/"
  #             service = "app"
  #             port = 80
  #           }
  #         ]
  #       }
  #     ]
  #   }
  # }
  secrets = {
    example = {
      DB_HOST = module.digitalocean.db_host
      DB_PORT = module.digitalocean.db_port
      DB_USER = module.digitalocean.db_user
      DB_PASSWORD = module.digitalocean.db_password
      DB_DATABASE = module.digitalocean.db_database
    }
  }
}
