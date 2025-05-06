# datarockets infrastructure

## Principles

### Single command setup

It should be possible to setup infrastructure for a new project quickly and easily, ideally with a single command. We can't achieve this with terraform alone, we may need to employ bash scripts and examples or templates.

Example:
```bash
datarockets-infrastructure new . --cloud aws --project acme
```

### Convention over configuration

Provided modules should have sensible defaults and be easy to start with.

### Security without overengineering

Modules should setup secure infrastructure by default.

Examples for AWS:
* Setup and asuume roles with least privileges to do different actions. Never attach AdministratorAccess policy to user directly and don't attach it to roles assumed by terraform to change infrastructure.
* Use demilitarized zone for services, don't expose them to the internet directly.
* Access AWS services and e.g. database over private network, not over public internet.

Examples for kubernetes:
* Use RBAC to restrict access to kubernetes resources for CI/CD pipelines.

### Upgradability

Modules should take burden of adoptation to a cloud provider changes.

Examples:
* aws/eks/auth should handle migration from aws-auth ConfigMap to EKS access entry APIs when needed without effort from the user.
* cert-manager and nginx inc. ingress controller should always be up to date in the latest version of modules.

### Growth with the project

Modules should allow users to amend and adopt infrastructure to project needs.

Examples:
* It must be possible to split one big infrastructure config into multiple ones. Imagine the case when we have a single config for everything but since a number of people involved grows we want to split it into `critical`, `iam`, and `infrastructure` configs so we have different admins for different parts.
* When a VPC is created in aws/eks module, it should be possible to get the VPC ID and other attributes to use them e.g. while creating a new subnet for database or a message broker.

### Ejectability

It must be possible and sometimes even necessary to eject from the provided modules by copying them to a project repository and modifying them to fit project needs.


## Examples

* [AWS EKS kubernetes cluster with deployment and ingress](examples/aws-eks-cluster)

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
