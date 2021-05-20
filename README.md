# datarockets infrastructure

## Examples

### AWS EKS cluster with kubernetes setup

```tf
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }

    nullresource = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.1"
    }

    kubernetes-alpha = {
      source = "hashicorp/kubernetes-alpha"
      version = "~> 0.3.3"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.1"
    }
  }
}

variable "app" {
  type = string
}

variable "environment" {
  default = "staging"
}

variable "region" {
  default = "ca-central-1"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      app = "<app-name>"
      environment = "staging"
    }
  }
}

module "aws" {
  source = "git@github.com:datarockets/infrastructure.git//aws?ref=aws"

  region = var.region
  app = var.app
  environment = var.environment
  ecr_repositories = ["api", "web"]
}

module "db" {
  source = "git@github.com:datarockets/infrastructure.git//aws/postgresql?ref=aws"

  region = var.region
  app = var.app
  environment = var.environment
  vpc_id = module.aws.vpc_id
  eks = {
    cluster_name = module.aws.eks.id
  }
  eks_private_subnets_cidr_blocks = module.aws.eks.private_subnets_cidr_blocks
}

data "aws_secretsmanager_secret" "secret_key_base" {
  name = "${var.app}/${var.environment}/api/secret_key_base"
}

data "aws_secretsmanager_secret_version" "secret_key_base" {
  secret_id = data.aws_secretsmanager_secret.secret_key_base.id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.aws.eks.id
}

provider "kubernetes" {
  host = module.aws.eks.endpoint
  cluster_ca_certificate = base64decode(module.aws.eks.ca_certificate)
  token = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host = module.aws.eks.endpoint
    cluster_ca_certificate = base64decode(module.aws.eks.ca_certificate)
    token = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes-alpha" {
  host = module.aws.eks.endpoint
  cluster_ca_certificate = base64decode(module.aws.eks.ca_certificate)
  token = data.aws_eks_cluster_auth.cluster.token
}

module "kubernetes" {
  source = "git@github.com:datarockets/infrastructure.git//k8s/basic?ref=main"

  depends_on = [
    module.aws
  ]

  app = "<app-name>"
  email = "<email>" # used for TLS certificate from Let's Encrypt
  services = {
    web = {
      replicas = 1
      image = "" # put image url here after you push it to ECR
      ports = [8080]
      env_from_secrets = []
    },
    api = {
      replicas = 1
      image = "" # put image url here after you push it to ECR
      ports = [3000]
      env_from_secrets = ["api"]
      env = {
        RAILS_LOG_TO_STDOUT = "true"
        PORT = "3000"
        DB_HOST = module.db.database.host
        DB_PORT = tostring(module.db.database.port)
        DB_POOL = "8"
        DB_DATABASE = module.db.database.database
        DB_USERNAME = module.db.database.username
      }
      init_container = {
        command = ["bin/rails", "db:migrate"]
        env_from_secrets = ["api"]
        env = {
          RAILS_LOG_TO_STDOUT = "true"
          PORT = "3000"
          DB_HOST = module.db.database.host
          DB_PORT = tostring(module.db.database.port)
          DB_POOL = "8"
          DB_DATABASE = module.db.database.database
          DB_USERNAME = module.db.database.username
        }
      }
    }
  }
  web_services = ["web", "api"]
  ingresses = {
    main = {
      disable_tls = true
      annotations = {}
      rules = [
        {
          host = "" # put hostname from ELB, created by nginx-ingress controller
          paths = [
            {
              path = "/"
              service = "web"
              port = 8080
            },
            {
              path = "/api"
              service = "api"
              port = 3000
            }
          ]
        }
      ]
    }
  }

  secrets = {
    api = {
      DB_PASSWORD = module.db.database_password
      SECRET_KEY_BASE = data.aws_secretsmanager_secret_version.secret_key_base.secret_string
    }
  }

  nginx_ingress_helm_chart_options = [
    {
      name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    }
  ]
}

output "cicd_user_key_id" {
  value = module.aws.cicd_key_id
}

output "cicd_user_key_secret" {
  value = module.aws.cicd_key_secret
  sensitive = true
}
```

### Digitalocean kubernetes for web services

Create managed kubernetes cluster and managed PostgreSQL database in Digitalocean and deploy simple web app consisting of one or mulple services.

The app will be deployed automatically, TLS certificates will be obtained automatically using Let's Encrypt.

Keep in mind that during the first run you won't have images in the registry yet, so you might put some placeholder images (e.g. `nginx:latest`) in `services` variable in `kubernetes` module.

Create `main.tf` in your repository:
```tf
module "digitalocean" {
  source = "git@github.com:datarockets/infrastructure.git//do/k8s?ref=v0.1.0"

  project = "sphere"
  region = "tor1"

  database = {
    name = "sphere"
    username = "sphere"
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
  source = "git@github.com:datarockets/infrastructure.git//k8s/basic?ref=v0.1.0"
  depends_on = [
    module.digitalocean
  ]

  app = "sphere"
  email = "sphere@datarockets.com"
  dcr_credentials = module.digitalocean.dcr_credentials_k8s
  services = {
    app = {
      replicas = 1
      image = "${module.digitalocean.dcr_endpoint}/app:latest"
      ports = [80]
      env_from_secrets = []
    }
    api = {
      replicas = 1
      image = "${module.digitalocean.dcr_endpoint}/api:latest"
      ports = [3000]
      env_from_secrets = ["sphere"]
      env = {
        DB_POOL_SIZE = 16
      }
      init_container = {
        command = ["bin/rails", "db:migrate"]
        env_from_secrets = ["sphere"]
        env = {
          DB_POOL_SIZE = 1
        }
      }
    }
    worker = {
      replicas = 1
      image = "${module.digitalocean.dcr_endpoint}/worker:latest"
      ports = []
      env = {
        QUEUES = "default:10"
      }
    }
  }
  web_services = ["app", "api"]
  ingresses = {
    "sphere.datarockets.com" = {
      annotations = {
      }
      rules = [
        {
          host = "sphere.datarockets.com"
          paths = [
            {
              path = "/api"
              service = "api"
              port = 3000
            },
            {
              path = "/"
              service = "app"
              port = 80
            }
          ]
        }
      ]
    }
  }
  secrets = {
    sphere = {
      DB_HOST = module.digitalocean.db_host
      DB_PORT = module.digitalocean.db_port
      DB_USER = module.digitalocean.db_user
      DB_PASSWORD = module.digitalocean.db_password
      DB_DATABASE = module.digitalocean.db_database
    }
  }
}
```

## Caveats

The configuration above will probably fail due to limitations of kubernetes-alpha provider: we try to create an Issuer using kubernetes-alpha and it raises an error because there are no CRD Issuer before we install cert-manager helm chart. Therefore, in order to apply the terraform config above you would need to apply it via multiple steps:
```
terraform apply -target=module.digitalocean
terraform apply -target=module.kubernetes.module.dependencies
terraform apply
```
