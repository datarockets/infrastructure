# DigitalOcean cluster

1. Generate personal access tokens for DigitalOcean API and save it to `DIGITALOCEAN_TOKEN` environment variable.

2. Create DO space for storing terraform state.

3. Generate Spaces access key and secret key.

4. Initialize the Terraform configuration with your Spaces access key and secret key:

```
terraform init -backend-config "access_key=SPACES_ACCESS_KEY" -backend-config "secret_key=SPACES_SECRET_KEY"
```

5. Due to limitations of kubernetes-alpha provider we have to apply configuration in multiple steps:

```
terraform apply -target module.eks
terraform apply -target module.database
terraform apply -target module.kubernetes.module.dependencies
terraform apply
```
