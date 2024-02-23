terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.1"
    }
  }

  backend "s3" {
    bucket         = "app-terraform-staging"
    key            = "state"
    region         = "ca-central-1"
    dynamodb_table = "app-terraform"
  }
}

variable "app" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  default = "ca-central-1"
}

variable "email" {
  description = "Email we use for Let's Encrypt certificate"
  type        = string
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      app         = var.app
      environment = var.environment
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

module "eks" {
  source = "https://github.com/datarockets/infrastructure.git//aws/eks?ref=v0.2.0"

  cluster_version = "1.20"

  app         = var.app
  environment = var.environment
  azs         = ["${var.region}a", "${var.region}b"]

  ecr_repositories = ["api"]
}

module "database" {
  source = "https://github.com/datarockets/infrastructure.git//aws/postgresql?ref=v0.2.0"

  eks = {
    cluster_name = "${var.app}-${var.environment}"
  }

  app                             = var.app
  environment                     = var.environment
  region                          = var.region
  vpc_id                          = module.eks.vpc_id
  eks_private_subnets_cidr_blocks = module.eks.private_cidr_blocks
  database_subnets = {
    "10.0.21.0/24" = "${var.region}a"
    "10.0.22.0/24" = "${var.region}b"
  }
}

module "kubernetes" {
  source = "git@github.com:datarockets/infrastructure.git//k8s/basic?ref=aws"

  depends_on = [module.eks]

  create_app_namespace = false
  app_namespace        = module.eks.app_namespace

  app   = var.app
  email = var.email

  services = {
    api = {
      replicas         = 2
      image            = "${module.eks.ecr_repository_urls.api}:latest"
      ports            = [3000]
      env_from_secrets = ["database"]
      env = {
        PORT             = "3000"
        DB_HOST          = module.database.database.host
        DB_PORT          = module.database.database.port
        DB_DATABASE_NAME = module.database.database.database
        DB_USERNAME      = module.database.database.username
        SECRET_KEY_BASE  = "supersecret"
      }
      init_container = {
        command          = ["bin/rails", "db:migrate"]
        env_from_secrets = ["database"]
        env = {
          PORT             = "3000"
          DB_HOST          = module.database.database.host
          DB_PORT          = module.database.database.port
          DB_DATABASE_NAME = module.database.database.database
          DB_USERNAME      = module.database.database.username
          SECRET_KEY_BASE  = "supersecret"
        }
      }
    }
  }
  web_services = ["api"]
  ingresses = {
    main = {
      annotations = {
        "acme.cert-manager.io/http01-edit-in-place" = "true"
      }
      rules = [
        {
          host = "example.com"
          paths = [
            {
              path    = "/"
              service = "api"
              port    = 3000
            }
          ]
        }
      ]
    }
  }
  secrets = {
    database = {
      DB_PASSWORD = module.database.database_password
    }
  }

  nginx_ingress_helm_chart_options = [
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    }
  ]
}
