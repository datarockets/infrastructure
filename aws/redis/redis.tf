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

variable "redis_subnets" {
  type = map(string)
}

variable "allow_security_group_ids" {
  type = list(string)
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
  name = "${var.app}-${var.environment}-elasticache-redis"
  description = "Redis security group"

  vpc_id = var.vpc_id

  lifecycle {
    create_before_destroy = true
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

resource "aws_security_group_rule" "redis_ingress" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id = aws_security_group.redis.id
  description = "Ingress to redis"
  type = "ingress"
  protocol = "tcp"
  from_port = aws_elasticache_cluster.redis.cache_nodes.0.port
  to_port = aws_elasticache_cluster.redis.cache_nodes.0.port
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "redis_egress" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id = aws_security_group.redis.id
  description = "Egress from redis"
  type = "egress"
  protocol = "tcp"
  from_port = 0
  to_port = 0
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "egress_to_redis" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id = each.value
  description = "Egress to redis"
  type = "egress"
  protocol = "tcp"
  from_port = aws_elasticache_cluster.redis.cache_nodes.0.port
  to_port = aws_elasticache_cluster.redis.cache_nodes.0.port
  source_security_group_id = aws_security_group.redis.id
}

resource "aws_security_group_rule" "ingress_from_redis" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id = each.value
  description = "Ingress from redis"
  type = "ingress"
  protocol = "tcp"
  from_port = 0
  to_port = 0
  source_security_group_id = aws_security_group.redis.id
}

output "host" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.address
}

output "port" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.port
}

output "security_group_id" {
  value = aws_security_group.redis.id
}
