# resource "aws_iam_role" "fargate_pod_node" {
#   name = "pod_node"
#   # I think there's a bug in EKS that use role arn but ignores the path so I had to disable path.
#   # path = "/service/fargate/"
#   description = "Service role to allow fargate nodes to pull containers from ECR"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = [
#           "eks.amazonaws.com",
#           "eks-fargate-pods.amazonaws.com"
#         ]
#       }
#     }]
#   })

#   managed_policy_arns = [
#     "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
#   ]
# }

# resource "aws_eks_fargate_profile" "kube_system" {
#   cluster_name = aws_eks_cluster.cluster.name
#   fargate_profile_name = "kube-system"
#   pod_execution_role_arn = aws_iam_role.fargate_pod_node.arn
#   subnet_ids = [for _, subnet in aws_subnet.private: subnet.id]

#   selector {
#     namespace = "kube-system"
#   }
# }

# resource "null_resource" "kubectl" {
#   depends_on = [
#     aws_eks_cluster.cluster,
#     aws_eks_fargate_profile.kube_system
#   ]
#   triggers = {
#     "cluster_arn" = aws_eks_cluster.cluster.arn,
#     "created_at" = aws_eks_cluster.cluster.created_at
#   }

#   provisioner "local-exec" {
#     when = create
#     command = "aws eks --region ${var.region} update-kubeconfig --name ${aws_eks_cluster.cluster.name}"
#   }
# }

# resource "null_resource" "patch-code-dns-to-work-on-fargate" {
#   depends_on = [
#     aws_eks_cluster.cluster,
#     aws_eks_fargate_profile.kube_system,
#     null_resource.kubectl
#   ]
#   triggers = {
#     "cluster_arn" = aws_eks_cluster.cluster.arn,
#     "created_at" = aws_eks_cluster.cluster.created_at
#   }

#   provisioner "local-exec" {
#     when = create
#     command = <<-EOC
#     kubectl patch deployment coredns -n kube-system --type json \
#     -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
#     EOC
#   }
# }
