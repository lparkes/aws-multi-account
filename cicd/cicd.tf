data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

variable "app" {
  type = string
}

variable "app_description" {
  type = string
}

variable "account_id" {
  type = string
}

resource "aws_codecommit_repository" "app" {
  repository_name = var.app
  description     = var.app_description
}

resource "aws_ecr_repository" "app" {
  name = var.app
}

resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PullAccessFromOtherAccounts",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::008062881613:root"
                ]
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}
POLICY
}

resource "aws_ecr_lifecycle_policy" "app_policy" {
  repository = aws_ecr_repository.app.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "mhc-cicd-codepipeline"
  acl    = "private"
}

# Create a role that allows AWS CodePipeline to assume it
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetUploadArchiveStatus",
        "codecommit:UploadArchive"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codepipeline" "app" {
  name     = var.app
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    # encryption_key {
    #   id   = "${data.aws_kms_alias.s3kmskey.arn}"
    #   type = "KMS"
    # }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["build_input"]

      configuration = {
        RepositoryName = aws_codecommit_repository.app.repository_name
        BranchName     = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["build_input"]
      output_artifacts = ["build_output"]
      version          = "1"
      #role_arn         = aws_iam_role.codebuild.arn
      
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  # stage {
  #   name = "Deploy"

  #   action {
  #     name            = "Deploy"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "CloudFormation"
  #     input_artifacts = ["build_output"]
  #     version         = "1"

  #     configuration = {
  #       ActionMode     = "REPLACE_ON_FAILURE"
  #       Capabilities   = "CAPABILITY_AUTO_EXPAND,CAPABILITY_IAM"
  #       OutputFileName = "CreateStackOutput.json"
  #       StackName      = "MyStack"
  #       TemplatePath   = "build_output::sam-templated.yaml"
  #     }
  #   }
  # }
}

resource "aws_codebuild_project" "build" {
  name          = var.app
  description   = "Build project for ${var.app}"
  #build_timeout = "5"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  # cache {
  #   type     = "S3"
  #   location = "${aws_s3_bucket.example.bucket}"
  # }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/docker:17.09.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.app
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "dev"
    }

    # environment_variable {
    #   name  = "SOME_KEY2"
    #   value = "SOME_VALUE2"
    #   type  = "PARAMETER_STORE"
    # }
  }

  # logs_config {
  #   cloudwatch_logs {
  #     group_name = "log-group"
  #     stream_name = "log-stream"
  #   }

  #   s3_logs {
  #     status = "ENABLED"
  #     location = "${aws_s3_bucket.example.id}/build-log"
  #   }
  # }

  source {
    type            = "CODEPIPELINE"

    # git_submodules_config {
    #     fetch_submodules = true
    # }
  }

  source_version = "master"

  # vpc_config {
  #   vpc_id = "${aws_vpc.example.id}"

  #   subnets = [
  #     "${aws_subnet.example1.id}",
  #     "${aws_subnet.example2.id}",
  #   ]

  #   security_group_ids = [
  #     "${aws_security_group.example1.id}",
  #     "${aws_security_group.example2.id}",
  #   ]
  # }

  # tags = {
  #   Environment = "Test"
  # }
}

resource "aws_iam_role" "codebuild" {
  name = "MHC_CodeBuild_${var.app}"

  path = "/service-role/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:${data.aws_region.current.name}:${var.account_id}:log-group:/aws/codebuild/*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:GetAuthorizationToken",
        "ecr:ListImages",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetRepositoryPolicy"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ecr:${data.aws_region.current.name}:${var.account_id}:repository/${var.app}*"
      ],
      "Action": [
        "ecr:UploadLayerPart",
        "ecr:BatchDeleteImage",
        "ecr:PutImage",
        "ecr:SetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:BatchCheckLayerAvailability"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}"
      ],
      "Action": [
        "s3:GetBucketVersioning",
        "s3:ListBucket"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}/*"
      ],
      "Action": [
        "s3:*"
      ]
    }
  ]
}
POLICY
}
