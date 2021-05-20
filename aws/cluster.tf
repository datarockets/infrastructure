resource "aws_iam_role" "eks_cluster" {
  name = "eks_cluster"
  path = "/service/eks/"
  description = "EKS service role to allow EKS cluster to manage AWS resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "eks.amazonaws.com",
            "eks-fargate-pods.amazonaws.com"
          ]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role = aws_iam_role.eks_cluster.name
}

resource "aws_iam_policy" "eks_cloudwatch_metrics_publisher" {
  name = "eks_cloudwatch_metrics_publisher_policy"
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [{
      "Action" = "cloudwatch:PutMetricData",
      "Resource" = "*",
      "Effect" = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_metrics_publisher" {
  policy_arn = aws_iam_policy.eks_cloudwatch_metrics_publisher.arn
  role = aws_iam_role.eks_cluster.name
}

resource "aws_iam_policy" "eks_loadbalancer" {
  name = "eks_loadbalancer_policy"
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [{
      "Action": [
          "elasticloadbalancing:*",
          "ec2:CreateSecurityGroup",
          "ec2:Describe*"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_loadbalancer" {
  policy_arn = aws_iam_policy.eks_loadbalancer.arn
  role = aws_iam_role.eks_cluster.name
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name = "/aws/eks/${var.app}/cluster"
  retention_in_days = 30
}

resource "aws_eks_cluster" "cluster" {
  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]
  name = var.app
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = concat(
      [for _, subnet in aws_subnet.private: subnet.id],
      [for _, subnet in aws_subnet.public: subnet.id]
    )
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
