resource "aws_iam_user" "cicd" {
  name = "cicd"
  path = "/automation/"

  tags = {
    type = "program"
  }
}

resource "aws_iam_access_key" "cicd" {
  user = aws_iam_user.cicd.name
}

resource "aws_iam_policy" "cicd" {
  name = "continous_delivery"
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
        Resource = [for repo in var.ecr_repositories: "arn:aws:ecr:*:*:repository/${var.app}/${repo}"]
      },
      {
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "cicd" {
  user = aws_iam_user.cicd.name
  policy_arn = aws_iam_policy.cicd.arn
}

output "cicd_key_id" {
  value = aws_iam_access_key.cicd.id
}

output "cicd_key_secret" {
  value = aws_iam_access_key.cicd.secret
  sensitive = true
}
