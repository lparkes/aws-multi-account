locals {
  dns_name = var.env == "prod" ? var.dns_name : "${var.dns_name}-${var.env}"
}

provider "aws" {
  alias = "cicd"
}

resource "aws_route53_record" "app" {

  provider = aws.cicd
  
  zone_id = var.dns_zone_id
  name    = "${local.dns_name}.${var.dns_root}"
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = false
  }
}
