terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
  }

  # --- add when bootstrapped:
  # backend "s3" {
  #   region         = var.region
  #   dynamodb_table = var.backend_dynamodb_table
  #   bucket         = var.backend_s3_bucket
  #   key            = "states/${var.config_name}/terraform.tfstate"

  #   assume_role = {
  #     role_arn     = var.aws_role_arn
  #     session_name = var.aws_user_name
  #   }
  # }
  # ---
}

provider "aws" {
  region = var.region

  # --- add when bootstrapped:
  # assume_role {
  #   role_arn     = var.aws_role_arn
  #   session_name = var.aws_user_name
  # }
  # ---

  default_tags {
    tags = {
      "ManagedBy" = var.config_name
    }
  }
}

data "aws_caller_identity" "current" {}

module "terraform_backend" {
  source = "./modules/aws/terraform_backend"

  s3_bucket      = var.backend_s3_bucket
  dynamodb_table = var.backend_dynamodb_table
}
