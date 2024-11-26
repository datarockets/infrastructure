terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "app" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list(string)
}

variable "cluster_version" {
  type = string
}

variable "legacy_iam_role_name" {
  type = string
  default = ""
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name = "${var.app}-${var.environment}"
  cidr = var.vpc_cidr

  azs = var.azs
  private_subnets = [for i, az in var.azs: "10.0.${i+1}.0/24"]
  public_subnets = [for i, az in var.azs: "10.0.${i+101}.0/24"]

  enable_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.26.1"

  cluster_name = "${var.app}-${var.environment}"
  cluster_version = var.cluster_version

  vpc_id = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  cluster_enabled_log_types = ["authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7

  eks_managed_node_groups = {
    default = {
      name_prefix = "default"
      instance_types = ["t3.small"]
      subnets = module.vpc.private_subnets
      disk_size = 20

      desired_capacity = 2
      min_capacity = 1
      max_capacity = 3
    }
  }

  # Arguments for upgradeability.
  # We can't modify cluster role name or security group w/o cluster recreation.
  # Se we try to maintain old role and security group name in order to avoid
  # cluster recreation.
  prefix_separator = ""
  iam_role_use_name_prefix = false
  iam_role_name = var.legacy_iam_role_name
  cluster_security_group_name = "${var.app}-${var.environment}"
  cluster_security_group_description = "EKS cluster security group."
}

# We need it to make cert-manager to work since it makes an http request to
# public self during the self-check while issuing a new certificate.
resource "aws_security_group_rule" "eks_node_egress_to_http" {
  security_group_id = module.eks.node_security_group_id
  description = "Egress to http (port 80)"
  type = "egress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  cidr_blocks = [
    "0.0.0.0/0"
  ]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster_id" {
  value = module.eks.cluster_id
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "private_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "public_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "aws_auth_configmap_yaml" {
  value = module.eks.aws_auth_configmap_yaml
}

output "eks_managed_node_group_default_iam_role_arn" {
  value = module.eks.eks_managed_node_groups.default.iam_role_arn
}
