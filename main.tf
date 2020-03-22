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

  cicd_stages = [
    {
      name = "dev"
      acct_id = "008062881613"
      canon_id = "46d335acb07134f5e23b9523b55b2f90f929c82dce455faa4b05e4c267e04fcf"
    }
  ]

  dns_root = "apps.must-have-coffee.com"
  dns_name = "www"
  
}

module "cicd" {
  source = "./cicd"

  app = local.app
  app_description = "A demo deployment of Gollum"
  account_id = local.cicd_acct_id

  cicd_stages = local.cicd_stages

  dns_root = local.dns_root
  
  providers = {
    aws = aws.cicd_admin
  }
}


module "gollumdev" {
  source = "./application"

  account_id = local.cicd_stages[0].acct_id
  env = local.cicd_stages[0].name
  
  cicd_acct_id = local.cicd_acct_id
  aws_region = "ap-southeast-2"

  cidr_block = "10.0.0.0/16"
  
  igw_name = "GOLLUM-DEV"
  vpc_name = "GOLLUM-VPC"

  app = local.app

  dns_name    = local.dns_name
  dns_root    = local.dns_root  
  dns_zone_id = module.cicd.route53_zone_id

  container = {
    cpu          = 256
    memory       = 512
    port         = 80
    count        = var.task_count
    health_check = "/"
  }

  providers = {
    aws      = aws.gollumdev_admin
    aws.cicd = aws.cicd_admin
  }

}

