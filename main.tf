terraform {
  backend "s3" {
    bucket = "mhc-terraform-state"
    key = "terraform_state"
    region = "ap-southeast-2"
    dynamodb_table = "mhc-terraform-lock"
    workspace_key_prefix = "app:"
  }
}

module "cicd" {
  source = "./cicd"

  app = "gollum"
  app_description = "A demo deployment of Gollum"
  account_id = var.cicd_acct_id
  
  providers = {
    aws = aws.cicd_admin
  }

}
