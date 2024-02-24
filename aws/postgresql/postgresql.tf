terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.38"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
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
  name        = "${var.app}-${var.environment}-rds-postgresql"
  description = "PostgreSQL security group"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.4.0"

  identifier = "${var.app}-${var.environment}"

  engine               = "postgres"
  family               = "postgres12"
  engine_version       = "12.8"
  major_engine_version = "12"
  instance_class       = "db.t2.micro"
  allocated_storage    = 10
  storage_encrypted    = false

  backup_window           = "03:00-06:00"
  backup_retention_period = 15
  maintenance_window      = "Mon:00:00-Mon:03:00"

  name                   = "main"
  username               = "root"
  create_random_password = true
  port                   = 5432

  subnet_ids = [for subnet in aws_subnet.database : subnet.id]

  vpc_security_group_ids = [aws_security_group.database.id]

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]
}

resource "aws_security_group_rule" "db_ingress" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id        = aws_security_group.database.id
  description              = "Ingress to PostgreSQL"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = module.rds.db_instance_port
  to_port                  = module.rds.db_instance_port
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "egress_to_db" {
  for_each = toset(var.allow_security_group_ids)

  security_group_id        = each.value
  description              = "Egress to PostgreSQL"
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
            image: postgres:latest
            command:
              - psql
              - "--echo-errors"
              - "-c"
              - "CREATE DATABASE ${var.app};"
              - "-c"
              - |
                CREATE USER ${var.app} WITH PASSWORD '${random_password.database.result}';
                GRANT ALL PRIVILEGES ON DATABASE ${var.app} TO ${var.app};
            env:
              - name: PGHOST
                value: "${module.rds.db_instance_address}"
              - name: PGPORT
                value: "${module.rds.db_instance_port}"
              - name: PGUSER
                value: "${module.rds.db_instance_username}"
              - name: PGPASSWORD
                value: "${module.rds.db_master_password}"
              - name: PGDATABASE
                value: "${module.rds.db_instance_name}"
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
