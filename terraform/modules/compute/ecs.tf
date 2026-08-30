# -----------------------------------------------------------------------------
# ECS Cluster (Fargate — sin instancias EC2 que administrar)
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "ecs-${local.nombre}"

  setting {
    name  = "containerInsights"
    value = "enabled" # métricas detalladas por servicio en CloudWatch
  }
}

# -----------------------------------------------------------------------------
# IAM: execution role (pull de ECR, logs) y task role (permisos de la app en runtime)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  name = "ecs-execution-${local.nombre}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "ecs-task-${local.nombre}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
# Nota: los permisos concretos del task role (acceso a Aurora, S3,
# SQS, Chime SDK) se adjuntan desde el módulo raíz de cada environment,
# una vez que existen los recursos de modules/data y modules/async.

# -----------------------------------------------------------------------------
# CloudWatch Log Groups — uno por microservicio
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  for_each          = var.servicios
  name              = "/ecs/${local.nombre}/${each.key}"
  retention_in_days = var.entorno == "prod" ? 90 : 14
}

# -----------------------------------------------------------------------------
# Task definitions + servicios ECS — uno por microservicio
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  for_each = var.servicios

  family                   = "${local.nombre}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name = each.key
      # Imagen "latest" como placeholder: el pipeline de CI/CD la reemplaza
      # por el tag real (commit sha) en cada deploy.
      image     = "${aws_ecr_repository.this[each.key].repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = each.value.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this[each.key].name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = each.key
        }
      }
      environment = [
        { name = "PAIS", value = var.pais },
        { name = "ENTORNO", value = var.entorno },
      ]
    }
  ])
}

resource "aws_ecs_service" "this" {
  for_each = var.servicios

  name            = "${local.nombre}-${each.key}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this[each.key].arn
    container_name   = each.key
    container_port   = each.value.container_port
  }

  depends_on = [aws_lb_listener_rule.this]
}

# -----------------------------------------------------------------------------
# Autoscaling — por CPU, uno por microservicio
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_target" "this" {
  for_each = var.servicios

  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = var.servicios

  name               = "cpu-autoscale-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.autoscaling_cpu_target
  }
}
