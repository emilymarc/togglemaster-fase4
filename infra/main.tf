provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ToggleMaster"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "eks" {
  source       = "./modules/eks"
  project_name = var.project_name

  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  depends_on = [module.networking]
}

module "data_stores" {
  source       = "./modules/data-stores"
  project_name = var.project_name

  vpc_id             = module.networking.vpc_id
  vpc_cidr           = module.networking.vpc_cidr
  private_subnet_ids = module.networking.private_subnet_ids

  db_username = var.db_username
  db_password = var.db_password
}
