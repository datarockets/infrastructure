# DigitalOcean cluster

1. Generate personal access tokens for DigitalOcean API and save it to `DIGITALOCEAN_TOKEN` environment variable.

2. Initialize the Terraform configuration:

```
terraform init
```

3. Due to limitations of kubernetes-alpha provider we have to apply configuration in multiple steps:

```
terraform apply -target module.eks
terraform apply -target module.database
terraform apply -target module.kubernetes.module.dependencies
terraform apply
```
