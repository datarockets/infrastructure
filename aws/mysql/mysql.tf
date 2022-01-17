terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.1"
    }
    null = {
      source = "hashicorp/null"
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

  vpc_id = var.vpc_id
  cidr_block = each.key
  availability_zone = each.value

  tags = {
    Name = "${var.app}-${var.environment}-database"
  }
}

resource "aws_security_group" "database" {
  name = "${var.app}-${var.environment}-rds-mysql"
  description = "MySQL security group"
  vpc_id = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "3.5.0"

  identifier = "${var.app}-${var.environment}"

  engine = "mysql"
  family = "mysql8.0"
  engine_version = "8.0.23"
  major_engine_version = "8.0"
  instance_class = "db.t2.micro"
  allocated_storage = 10

  backup_window = "03:00-06:00"
  backup_retention_period = 15
  maintenance_window = "Mon:00:00-Mon:03:00"

  name = "main"
  username = "root"
  create_random_password = true
  port = 3306

  subnet_ids = [for subnet in aws_subnet.database: subnet.id]

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

  security_group_id = aws_security_group.database.id
  description = "Ingress to mysql"
  type = "ingress"
  protocol = "tcp"
  from_port = module.rds.db_instance_port
  to_port = module.rds.db_instance_port
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "db_egress" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id = aws_security_group.database.id
  description = "Egress from mysql"
  type = "egress"
  protocol = "tcp"
  from_port = 0
  to_port = 0
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "egress_to_db" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id = each.value
  description = "Egress to mysql"
  type = "egress"
  protocol = "tcp"
  from_port = module.rds.db_instance_port
  to_port = module.rds.db_instance_port
  source_security_group_id = aws_security_group.database.id
}

resource "aws_security_group_rule" "ingress_from_db" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id = each.value
  description = "Ingress from mysql"
  type = "ingress"
  protocol = "tcp"
  from_port = 0
  to_port = 0
  source_security_group_id = aws_security_group.database.id
}

resource "random_password" "database" {
  length = 20
  special = true
}

# TODO: use kubernetes_job resource with ttl_seconds_after_finished argument when
# upgraded to Kubernetes 1.21.
# Since 1.21 TTL Controller is enabled by default.
#
# If the job pod fails with error, see logs for failed pod:
#   kubectl -n <namespace> get pods
# and destroy the job for proper recreation later:
#   kubectl -n <namespace> delete jobs/database-creator
resource "null_resource" "database" {
  depends_on = [
    module.rds,
    random_password.database
  ]

  triggers = {
    rds_instance_id = module.rds.db_instance_resource_id
  }

  provisioner "local-exec" {
    command = <<-EOC
    set -e

    aws eks --region ${var.region} update-kubeconfig --name ${var.eks.cluster_name}

    cat << JOB | kubectl -n default apply -f -
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: database-creator
    spec:
      template:
        spec:
          containers:
          - name: database-creator
            image: mysql:8.0.23
            command:
              - "mysql"
              - "--user=${module.rds.db_instance_username}"
              - "--password=${module.rds.db_master_password}"
              - "--host=${module.rds.db_instance_address}"
              - "--port=${module.rds.db_instance_port}"
              - "--database=${module.rds.db_instance_name}"
              - "-e"
              - |
                CREATE DATABASE ${var.app};
                CREATE USER ${var.app} IDENTIFIED BY '${random_password.database.result}';
                GRANT ALL PRIVILEGES ON ${var.app}.* TO ${var.app};
          restartPolicy: Never
      backoffLimit: 0
    JOB

    kubectl -n default wait --for=condition=complete jobs/database-creator
    kubectl -n default delete jobs/database-creator
    EOC
  }
}

output "database" {
  value = {
    host = module.rds.db_instance_address
    port = module.rds.db_instance_port
    username = var.app
    database = var.app
  }
}

output "database_password" {
  value = random_password.database.result
  sensitive = true
}

output "security_group_id" {
  value = aws_security_group.database.id
}
