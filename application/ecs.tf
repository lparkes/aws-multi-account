
resource "aws_ecs_cluster" "app" {
  name = "${var.app}-${var.env}"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "${var.app}-${var.env}"
  retention_in_days = 365
}

resource "aws_ecs_task_definition" "app" {

  family                   = "${var.app}-${var.env}"
  requires_compatibilities = [ "FARGATE" ]
  network_mode             = "awsvpc"
  cpu                      = var.container.cpu
  memory                   = var.container.memory
  # FIXME - these two roles should be different
  execution_role_arn       = aws_iam_role.ecs_role.arn
  task_role_arn            = aws_iam_role.ecs_role.arn

  container_definitions = <<DEFS
[
  {
    "name": "${var.app}",
    "image": "${var.cicd_acct_id}.dkr.ecr.ap-southeast-2.amazonaws.com/${var.app}:${var.env}",
    "portMappings": [
      {
	"containerPort": ${var.container.port},
	"hostPort": ${var.container.port},
	"protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
	"awslogs-region": "${var.aws_region}",
	"awslogs-group": "${aws_cloudwatch_log_group.app.name}",
	"awslogs-stream-prefix": "${var.app}"
      }
    }
  }
]
DEFS
}

# This role is used for both execution and task, which isn't quite right.
resource "aws_iam_role" "ecs_role" {
  name_prefix = "iam-${var.app}-${var.env}-Role-"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

locals {
  policies = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy",
    "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AWSCodeDeployDeployerAccess"
  ]
}

resource "aws_iam_role_policy_attachment" "ecs" {
  for_each = toset(local.policies)
  
  role       = aws_iam_role.ecs_role.name
  policy_arn = each.key
}

resource "aws_security_group" "app_tasks" {
  description = "${var.app} tasks"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description     = "Access from ALB"
    from_port       = var.container.port
    to_port         = var.container.port
    protocol        = "tcp"
    security_groups = [ aws_security_group.alb.id ]
  }

  egress {
    description = "Access to ECR"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "app" {
  name            = var.app
  cluster         = aws_ecs_cluster.app.id
  desired_count   = var.container.count
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.app.arn

  # The rule ties the ELB parts together in the way that AWS
  # requires for load_balancer.target_group_arn to work.
  depends_on = [ aws_lb_listener_rule.app ]

  network_configuration {
    # XXX We need a more intuitive way to find application subnets
    subnets          = [ aws_subnet.net[1].id, aws_subnet.net[2].id ]
    security_groups  = [ aws_security_group.app_tasks.id ]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.app
    container_port   = var.container.port
  }

  lifecycle {
    ignore_changes = [ desired_count ]
  }
}

resource "aws_lb_target_group" "app" {
  name                 = var.app
  protocol             = "HTTP"
  port                 = var.container.port
  vpc_id               = aws_vpc.dev.id
  target_type          = "ip"
  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    enabled         = true	# The default
    cookie_duration = 86400	# 1 day (the default)
  }
  
  health_check {
    path     = var.container.health_check
    protocol = "HTTP"
    matcher  = "200-404"
  }
  
  tags = {
    Description = "Target group for ${var.app}-${var.env}"
    Environment = var.env
    Application = var.app
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.app.arn
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    # FIXME
    host_header {
      values = [ "www-dev.apps.must-have-coffee.com" ]
    }
  }
}

resource "aws_lb" "app" {
  name               = "ecs-external-alb-${var.env}"
  internal           = false
  load_balancer_type = "application"
  subnets            = [ aws_subnet.net[5].id, aws_subnet.net[6].id ]
  security_groups    = [ aws_security_group.alb.id ]

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    enabled = true
  }

  tags = {
    Name = "ecs-external-alb-${var.env}"
    Environment = var.env
  }
}

resource "aws_security_group" "alb" {
  description = "Security group for ECS external ALB"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description     = "Access to ALB listener"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "Access to ALB listener"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Access to the application"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [ var.cidr_block ]
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  # port              = "443"
  # protocol          = "HTTPS"
  # ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  # certificate_arn   = "!Ref ACMCertificateArn"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# resource "aws_lb_target_group" "default" {
#   name                 = var.app
#   protocol             = "HTTP"
#   port                 = 80
#   vpc_id               = aws_vpc.dev.id
#   target_type          = "ip"
#   #deregistration_delay = 30

#   stickiness {
#     type            = "lb_cookie"
#     enabled         = true	# The default
#     cookie_duration = 86400	# 1 day (the default)
#   }
  
#   health_check {
#     path     = "/internal/healthcheck"
#     protocol = "HTTP"
#     #matcher  = "200-404"
#   }
  
#   tags = {
#     Description = "Default target group"
#     Environment = var.env
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }
