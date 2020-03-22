variable "alb_accounts" {
  type = map(string)
  default = {
    "us-east-1" = "127311923021"
    "us-east-2" = "033677994240"
    "us-west-1" = "027434742980"
    "us-west-2" = "797873946194"
    "ca-central-1" = "985666609251"
    "eu-central-1" = "054676820928"
    "eu-west-1" = "156460612806"
    "eu-west-2" = "652711504416"
    "eu-west-3" = "009996457667"
    "eu-north-1" = "897822967062"
    "ap-east-1" = "754344448648"
    "ap-northeast-1" = "582318560864"
    "ap-northeast-2" = "600734575887"
    "ap-northeast-3" = "383597477331"
    "ap-southeast-1" = "114774131450"
    "ap-southeast-2" = "783225319266"
    "ap-south-1" = "718504428378"
    "me-south-1" = "076674570225"
    "sa-east-1" = "507241528517"
  }
}

variable "account_id" {
  type = string
}

variable "cicd_acct_id" {
  type = string
}

variable "env" {
  type = string
  description = "The SDLC environment."
}

variable "aws_region" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "igw_name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "container" {
  type = map(string)
}

variable "app" {
  type        = string
  description = "A short name for the application"
}

variable "dns_name" {
  type        = string
  description = "The unqualified DNS name for the application"
}

variable "dns_root" {
  type        = string
  description = "The FQDN of the DNS zone"
}

variable "dns_zone_id" {
  type        = string
  description = "The aws_route53_zone id"
}
