terraform {
  backend "s3" {
    bucket = "mhc-terraform-state"
    key = "terraform_state"
    region = "ap-southeast-2"
    dynamodb_table = "mhc-terraform-lock"
    workspace_key_prefix = "app:"
  }
}

locals {
  app = "gollum"

  cicd_acct_name = "mhc-cicd"
  cicd_acct_id = "255013836461"

  cicd_stages = [ "dev" ]
}

module "cicd" {
  source = "./cicd"

  app = local.app
  app_description = "A demo deployment of Gollum"
  account_id = local.cicd_acct_id
  
  providers = {
    aws = aws.cicd_admin
  }

}


module "gollumdev" {
  source = "./application"

  account_id = "008062881613"

  env = "dev"
  cicd_acct_id = local.cicd_acct_id
  aws_region = "ap-southeast-2"

  cidr_block = "10.0.0.0/16"
  
  igw_name = "ATFL-DEV"
  vpc_name = "ATFL-VPC"

  app = local.app

  container = {
    cpu          = 256
    memory       = 512
    port         = 80
    count        = var.task_count
    health_check = "/"
  }

  providers = {
    aws = aws.gollumdev_admin
  }

}

