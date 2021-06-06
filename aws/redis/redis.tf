terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "app" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "eks_private_subnets_cidr_blocks" {
  type = set(string)
}

variable "redis_subnets" {
  type = map(string)
}

resource "aws_subnet" "redis" {
  for_each = var.redis_subnets

  vpc_id = var.vpc_id

  cidr_block = each.key
  availability_zone = each.value
}

resource "aws_elasticache_subnet_group" "redis" {
  name = "${var.app}-${var.environment}-redis-subnet-group"
  subnet_ids = [for subnet in aws_subnet.redis: subnet.id]
}

resource "aws_security_group" "redis" {
  name = "${var.app}-${var.environment}-redis"
  description = "Allows access from EKS private subnets to Redis"

  vpc_id = var.vpc_id

  ingress {
    description = "From EKS private subnets to Redis"
    from_port = 6379
    to_port = 6379
    protocol = "tcp"
    cidr_blocks = var.eks_private_subnets_cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id = "${var.app}-${var.environment}-redis"

  engine = "redis"
  engine_version = "6.x"
  parameter_group_name = "default.redis6.x"

  node_type = "cache.t3.micro"
  num_cache_nodes = 1

  port = 6379

  snapshot_retention_limit = 3

  security_group_ids = [aws_security_group.redis.id]
  subnet_group_name = aws_elasticache_subnet_group.redis.name
}

output "host" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.address
}

output "port" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.port
}
