# We shouldn't need this because we won't be using CloudFormation
# unless it ends up being convenient for container deployment from
# CodePipeline
resource "aws_s3_bucket" "cloudformation" {
  bucket = "cloudformation-${var.account_id}-${var.env}"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
	sse_algorithm = "AES256"
      }
    }
  }
}

# Surely this is only needed in the CI/CD account?
resource "aws_s3_bucket" "codepipeline" {
  bucket = "codepipeline-${var.account_id}-${var.env}"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
	sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket" "lambda" {
  bucket = "lambda-${var.account_id}-${var.env}"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
	sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "logs-${var.account_id}-${var.env}"
  
  versioning {
    enabled = true
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
	sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    enabled = true
    id = "INFREQUENTACCESS"
    transition {
      storage_class = "STANDARD_IA"
      days = 30
    }
  }

  lifecycle_rule {
    enabled = true
    id = "DELETE"
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "AllowAwsLogging",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": 
      {
	"AWS": "arn:aws:iam::${var.alb_accounts[var.aws_region]}:root"
      },  
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.logs.arn}/AWSLogs/${var.account_id}/*"
    }
  ]
}
POLICY
}

resource "aws_s3_bucket" "ssm" {
  bucket = "ssm-${var.account_id}-${var.env}"
  
  versioning {
    enabled = true
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
	sse_algorithm = "AES256"
      }
    }
  }
  
  lifecycle_rule {
    enabled = true
    id = "DELETE"
    expiration {
      days = 7
    }
  }  
}

resource "aws_iam_role" "deploy" {
  name = "deploy-${var.env}"
  path = "/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
	"AWS": "arn:aws:iam::${var.cicd_acct_id}:root",
      },
      "Effect": "Allow"
    }
  ]
}
POLICY
  
}

resource "aws_iam_role_policy" "cloudformation" {
  name = "cloudformation"
  role = aws_iam_role.deploy.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
	"cloudformation:*"
      ],
      "Resource": "arn:aws:cloudformation:*:*:stack/app-*-${var.env}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "iam" {
  name = "iam"
  role = aws_iam_role.deploy.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
	"iam:PassRole",
	"iam:ListRoles"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "kms" {
  name = "iam"
  role = aws_iam_role.deploy.name

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:Encrypt",
                "kms:GenerateDataKey",
                "kms:ReEncryptTo",
                "kms:DescribeKey",
                "kms:ReEncryptFrom"
            ],
            "Resource": "arn:aws:kms:ap-southeast-2:${var.cicd_acct_id}:*"
        }
    ]
}
POLICY
}


resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# FIXME - full access??
resource "aws_iam_role_policy_attachment" "deploy_ecs" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}
