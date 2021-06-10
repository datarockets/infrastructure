# AWS EKS cluster

Due to limitations of kubernetes-alpha provider we have to apply configuration in multiple steps:

```
terraform apply -target module.eks
terraform apply -target module.database
terraform apply -target module.kubernetes.module.dependencies
terraform apply
```
