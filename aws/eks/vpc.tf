variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list(string)
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.app}-${var.environment}"
  cidr = var.vpc_cidr

  azs = var.azs
  private_subnets = [for i, az in var.azs: "10.0.${i+1}.0/24"]
  public_subnets = [for i, az in var.azs: "10.0.${i+101}.0/24"]

  enable_nat_gateway = true
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
