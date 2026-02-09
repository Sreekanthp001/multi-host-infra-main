resource "aws_lb_target_group" "client" {
  name        = "${var.project_name}-${var.client_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener_rule" "client" {
  listener_arn = var.alb_https_listener_arn
  priority     = var.priority_index

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.client.arn
  }

  condition {
    host_header {
      values = [var.domain_name]
    }
  }
}

resource "aws_ecs_service" "client" {
  name            = "${var.project_name}-${var.client_name}-svc"
  cluster         = var.ecs_cluster_id
  task_definition = var.task_definition_arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.ecs_service_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.client.arn
    container_name   = "web"
    container_port   = 80
  }

  depends_on = [aws_lb_listener_rule.client]
}
