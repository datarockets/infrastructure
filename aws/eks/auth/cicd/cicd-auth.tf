terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.7"
    }
  }
}

variable "app" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "kubernetes_app_namespace" {
  type = string
}

variable "ecr_repository_arns" {
  type = list(string)
}

resource "aws_iam_user" "cicd" {
  name = "cicd"
  path = "/automation/${var.app}/${var.environment}/"

  tags = {
    type = "program"
  }
}

resource "aws_iam_access_key" "cicd" {
  user = aws_iam_user.cicd.name
}

resource "aws_iam_policy" "cicd" {
  name        = "continous_delivery"
  path        = "/automation/${var.app}/${var.environment}/"
  description = "Allows to push images to ECR, use CodePipeline and rollout updates in EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:ListTagsForResource",
          "ecr:PutImage",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:UploadLayerPart",
        ]
        Effect   = "Allow"
        Resource = var.ecr_repository_arns
      },
      {
        Action = [
          "eks:DescribeCluster"
        ]
        Effect   = "Allow"
        Resource = [var.cluster_arn]
      },
      {
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "cicd" {
  user       = aws_iam_user.cicd.name
  policy_arn = aws_iam_policy.cicd.arn
}

resource "kubernetes_role" "cicd" {
  metadata {
    namespace = var.kubernetes_app_namespace
    name      = "cicd"
    labels = {
      app = var.app
    }
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "cicd" {
  metadata {
    namespace = var.kubernetes_app_namespace
    name      = "cicd"
    labels = {
      app = var.app
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.cicd.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = "cicd"
  }
}

output "iam_user" {
  value = {
    arn  = aws_iam_user.cicd.arn
    name = aws_iam_user.cicd.name
  }
}

output "iam_user_key_id" {
  value = aws_iam_access_key.cicd.id
}

output "iam_user_key_secret" {
  value     = aws_iam_access_key.cicd.secret
  sensitive = true
}

output "kubernetes_group" {
  value = kubernetes_role_binding.cicd.subject[0].name
}
