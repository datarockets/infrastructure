variable "app" {
  type = string
}

variable "environment" {
  type = string
}

variable "repositories" {
  type    = set(string)
  default = []
}

resource "aws_ecr_repository" "repository" {
  for_each = var.repositories

  name = "${var.app}/${var.environment}/${each.value}"
}

resource "aws_ecr_lifecycle_policy" "keep_last_10" {
  for_each = var.repositories

  repository = aws_ecr_repository.repository[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "repository_urls" {
  value = { for name in var.repositories :
    name => aws_ecr_repository.repository[name].repository_url
  }
}

output "repository_arns" {
  value = [for name in var.repositories :
    aws_ecr_repository.repository[name].arn
  ]
}
