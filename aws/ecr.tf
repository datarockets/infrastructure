variable "ecr_repositories" {
  type = set(string)
}

resource "aws_ecr_repository" "ecr_repository" {
  for_each = var.ecr_repositories

  name = "${var.app}/${each.key}"
}
