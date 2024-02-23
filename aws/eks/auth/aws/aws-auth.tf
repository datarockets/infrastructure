variable "app" {
  type = string
}

variable "environment" {
  type = string
}

variable "masters_aws_groups" {
  type = set(string)
}

variable "node_group_iam_role_arn" {
  type = string
}

variable "users" {
  type = list(
    object({
      userarn  = string
      username = string
      groups   = list(string)
    })
  )
}

data "aws_iam_group" "masters_groups" {
  for_each = var.masters_aws_groups

  group_name = each.value
}

locals {
  masters_aws_users = flatten([for group in data.aws_iam_group.masters_groups :
    [for user in group.users :
      {
        userarn  = user.arn
        username = user.user_name
        groups   = ["system:masters"]
      }
    ]
  ])
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapAccounts = jsonencode([])
    mapRoles = yamlencode([
      {
        rolearn  = var.node_group_iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ])
    mapUsers = yamlencode(concat(
      local.masters_aws_users,
      var.users
    ))
  }
}
