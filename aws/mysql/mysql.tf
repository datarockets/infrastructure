terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}

variable "region" {
  type = string
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

variable "database_subnets" {
  type = map(string)
}

variable "eks" {
  type = object({
    cluster_name = string
  })
}

variable "allow_security_group_ids" {
  type = list(string)
}

resource "aws_subnet" "database" {
  for_each = var.database_subnets

  vpc_id            = var.vpc_id
  cidr_block        = each.key
  availability_zone = each.value

  tags = {
    Name = "${var.app}-${var.environment}-database"
  }
}

resource "aws_security_group" "database" {
  name        = "${var.app}-${var.environment}-rds-mysql"
  description = "MySQL security group"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "3.5.0"

  identifier = "${var.app}-${var.environment}"

  engine               = "mysql"
  family               = "mysql8.0"
  engine_version       = "8.0.23"
  major_engine_version = "8.0"
  instance_class       = "db.t2.micro"
  allocated_storage    = 10

  backup_window           = "03:00-06:00"
  backup_retention_period = 15
  maintenance_window      = "Mon:00:00-Mon:03:00"

  name                   = "main"
  username               = "root"
  create_random_password = true
  port                   = 3306

  subnet_ids = [for subnet in aws_subnet.database : subnet.id]

  vpc_security_group_ids = [aws_security_group.database.id]

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]
}

resource "aws_security_group_rule" "db_ingress" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id        = aws_security_group.database.id
  description              = "Ingress to mysql"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = module.rds.db_instance_port
  to_port                  = module.rds.db_instance_port
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "egress_to_db" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id        = each.value
  description              = "Egress to mysql"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = module.rds.db_instance_port
  to_port                  = module.rds.db_instance_port
  source_security_group_id = aws_security_group.database.id
}

resource "random_password" "database" {
  length  = 20
  special = true
}

resource "kubernetes_job_v1" "database_creator" {
  depends_on = [
    module.rds,
    random_password.database
  ]

  metadata {
    generate_name = "${var.app}-database-creator"
  }

  spec {
    template {
      metadata {}
      spec {
        container {
          name  = "database-creator"
          image = "mysql:8.0.23"
          command = [
            "mysql",
            "--user=${module.rds.db_instance_username}",
            "--password=${module.rds.db_master_password}",
            "--host=${module.rds.db_instance_address}",
            "--port=${module.rds.db_instance_port}",
            "--database=${module.rds.db_instance_name}",
            "-e",
            <<EOC
            CREATE DATABASE ${var.app};
            CREATE USER ${var.app} IDENTIFIED BY '${sensitive(random_password.database.result)}';
            GRANT ALL PRIVILEGES ON ${var.app}.* TO ${var.app};
            EOC
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit              = 0
    ttl_seconds_after_finished = 60
  }
  wait_for_completion = true
  timeouts {
    create = "5m"
  }
}

output "database" {
  value = {
    host     = module.rds.db_instance_address
    port     = module.rds.db_instance_port
    username = var.app
    database = var.app
  }
}

output "database_password" {
  value     = random_password.database.result
  sensitive = true
}

output "security_group_id" {
  value = aws_security_group.database.id
}
