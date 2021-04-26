# datarockets infrastructure

## Examples

### Digitalocean kubernetes for web services

Create managed kubernetes cluster and managed PostgreSQL database in Digitalocean and deploy simple web app consisting of one or mulple services.

The app will be deployed automatically, TLS certificates will be obtained automatically using Let's Encrypt.

Keep in mind that during the first run you won't have images in the registry yet, so you might put some placeholder images (e.g. `nginx:latest`) in `services` variable in `kubernetes` module.

Create `main.tf` in your repository:
```tf
module "digitalocean" {
  source = "git@github.com:datarockets/infrastructure.git//do/k8s?ref=v0.0.1"

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
  source = "git@github.com:datarockets/infrastructure.git//k8s/basic?ref=v0.0.1"
  depends_on = [
    module.digitalocean
  ]

  project = "sphere"
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
      DB_USER = module.digitalocean.db_user
      DB_PASSWORD = module.digitalocean.db_password
      DB_DATABASE = module.digitalocean.db_database
    }
  }
}
```
