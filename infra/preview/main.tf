data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = var.tfstate_bucket
    key    = "base/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  route_prefix = "/pr-${var.pr_number}"
}

resource "aws_lb_target_group" "preview" {
  name                 = "pr-${var.pr_number}-tg"
  port                 = 8000
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.terraform_remote_state.base.outputs.vpc_id
  deregistration_delay = 10 # Speeds up PR teardown

  health_check {
    path                = "${local.route_prefix}/healthz"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener_rule" "preview" {
  listener_arn = data.terraform_remote_state.base.outputs.alb_listener_arn
  priority     = 100 + var.pr_number

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.preview.arn
  }

  condition {
    path_pattern {
      values = [local.route_prefix, "${local.route_prefix}/*"]
    }
  }
}

resource "aws_ecs_task_definition" "preview" {
  family                   = "pr-engine-pr-${var.pr_number}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.terraform_remote_state.base.outputs.ecs_execution_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image_uri
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "ROUTE_PREFIX", value = local.route_prefix },
        { name = "PR_NUMBER", value = tostring(var.pr_number) },
        { name = "GIT_SHA", value = var.git_sha }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = data.terraform_remote_state.base.outputs.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "pr-${var.pr_number}"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "preview" {
  name                              = "pr-${var.pr_number}-svc"
  cluster                           = data.terraform_remote_state.base.outputs.ecs_cluster_name
  task_definition                   = aws_ecs_task_definition.preview.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  force_new_deployment              = true
  wait_for_steady_state             = true
  health_check_grace_period_seconds = 30
  propagate_tags                    = "SERVICE"

  network_configuration {
    subnets          = data.terraform_remote_state.base.outputs.public_subnet_ids
    security_groups  = [data.terraform_remote_state.base.outputs.ecs_security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.preview.arn
    container_name   = "app"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener_rule.preview]
}