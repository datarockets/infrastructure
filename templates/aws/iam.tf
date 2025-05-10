module "iam" {
  source = "./modules/aws/iam"

  roles = {
    Administrator = {
      assumers = {
        iam_users = [
          {
            arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.aws_user_name}"
          }
        ],
      }
      policies = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
      ]
      terraforming = {
        state_s3_bucket      = module.terraform_backend.s3_bucket
        state_dynamodb_table = module.terraform_backend.dynamodb_table
        region               = var.region
        states = [
          "states/${var.config_name}/terraform.tfstate",
        ]
      }
    }
  }
}

# --- remove when bootstrapped:
output "aws_role_arn" {
  value = module.iam.roles["Administrator"].arn
}
# ---
