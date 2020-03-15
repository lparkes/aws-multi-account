

provider "aws" {

  alias = "cicd_admin"
  
  profile="default"
  assume_role {
    role_arn = "arn:aws:iam::255013836461:role/mhc-cicd_Admin"
  }

  version = "~> 2.0"
  region  = "ap-southeast-2"

}

provider "aws" {

  alias = "gollumdev_admin"
  
  profile="default"
  assume_role {
    role_arn = "arn:aws:iam::008062881613:role/gollumdev_Admin"
  }

  version = "~> 2.0"
  region  = "ap-southeast-2"

}
