# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name   = "alb-${local.nombre}"
  vpc_id = var.vpc_id

  ingress {
    description = "HTTPS desde Internet (o desde CloudFront si se restringe mas adelante)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-alb-${local.nombre}" }
}

resource "aws_security_group" "ecs_tasks" {
  name   = "sg-ecs-${local.nombre}"
  vpc_id = var.vpc_id

  ingress {
    description     = "Solo tráfico proveniente del ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-ecs-${local.nombre}" }
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------
resource "aws_lb" "this" {
  name               = "alb-${local.nombre}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = { Pais = var.pais, Entorno = var.entorno }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No encontrado"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -----------------------------------------------------------------------------
# Target groups + reglas de ruteo — un target group por microservicio,
# ruteado por path (ej: /hce/* -> target group de hce)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "this" {
  for_each = var.servicios

  name        = "tg-${var.pais}-${var.entorno}-${each.key}"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # requerido por Fargate

  health_check {
    path                = each.value.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = { Servicio = each.key }
}

resource "aws_lb_listener_rule" "this" {
  for_each = var.servicios

  listener_arn = aws_lb_listener.https.arn
  priority     = index(keys(var.servicios), each.key) + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }
}
