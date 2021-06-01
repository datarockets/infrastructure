variable "ecr_repositories" {
  type = set(string)
  default = []
}

resource "aws_ecr_repository" "ecr_repository" {
  for_each = var.ecr_repositories

  name = "${var.app}/${var.environment}/${each.value}"
}

resource "aws_ecr_lifecycle_policy" "keep_last_10" {
  for_each = var.ecr_repositories

  repository = aws_ecr_repository.ecr_repository[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description = "Keep last 10 tagged images"
        selection = {
          tagStatus = "tagged"
          tagPrefixList = ["v"]
          countType = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description = "Expire images older than 14 days"
        selection = {
          tagStatus = "untagged"
          countType = "sinceImagePushed"
          countUnit = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_urls" {
  value = {for name in var.ecr_repositories:
    name => aws_ecr_repository.ecr_repository[name].repository_url
  }
}
