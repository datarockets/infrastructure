variable "cluster_version" {
  type = string
}

variable "masters_aws_groups" {
  type = set(string)
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list(string)
}

data "aws_iam_group" "masters_groups" {
  for_each = var.masters_aws_groups

  group_name = each.value
}

locals {
  masters_aws_users = flatten([for group in data.aws_iam_group.masters_groups :
    [for user in group.users :
      {
        userarn = user.arn
        username = user.user_name
        groups = ["system:masters"]
      }
    ]
  ])
  cicd_users = [
    {
      userarn = aws_iam_user.cicd.arn
      username = aws_iam_user.cicd.name
      groups = ["cicd"]
    }
  ]

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.11.3"

  name = "${var.app}-${var.environment}"
  cidr = var.vpc_cidr

  azs = var.azs
  private_subnets = [for i, az in var.azs: "10.0.${i+1}.0/24"]
  public_subnets = [for i, az in var.azs: "10.0.${i+101}.0/24"]

  enable_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"

  cluster_name = "${var.app}-${var.environment}"
  cluster_version = var.cluster_version

  vpc_id = module.vpc.vpc_id
  subnets = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  cluster_enabled_log_types = ["authenticator", "controllerManager", "scheduler"]
  cluster_log_retention_in_days = 7

  node_groups = {
    default = {
      name_prefix = "default"
      instance_types = ["t3.small"]
      subnets = module.vpc.private_subnets
      disk_size = 20

      desired_capacity = 1
      min_capacity = 1
      max_capacity = 2
    }
  }

  map_users = concat(local.masters_aws_users, local.cicd_users)

  write_kubeconfig = false
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster_id" {
  value = module.eks.cluster_id
}

output "private_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "public_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}
