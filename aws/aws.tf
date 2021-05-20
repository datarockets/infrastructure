variable "region" {
  type = string
}

variable "app" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnets" {
  type = map(string)
  default = {
    "10.0.1.0/24" = "ca-central-1a",
    "10.0.2.0/24" = "ca-central-1b"
  }
}

variable "public_subnets" {
  type = map(string)
  default = {
    "10.0.101.0/24" = "ca-central-1a"
    "10.0.102.0/24" = "ca-central-1b"
  }
}

variable "private_subnet_nat_map" {
  type = map(string)
  default = {
    "10.0.1.0/24" = "10.0.101.0/24"
    "10.0.2.0/24" = "10.0.102.0/24"
  }
}

output "eks" {
  value = {
    id = aws_eks_cluster.cluster.id
    endpoint = aws_eks_cluster.cluster.endpoint
    ca_certificate = aws_eks_cluster.cluster.certificate_authority[0].data
    private_subnets_cidr_blocks = keys(var.private_subnets)
    public_subnets_cidr_blocks = keys(var.public_subnets)
  }
}
