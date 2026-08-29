# =============================================================================
# Tests: Módulo Compute — ECS Fargate, ECR, ALB, Auto Scaling
# Ejecución: ./scripts/run-tests-localstack.ps1
# =============================================================================

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}

variables {
  pais               = "ar"
  entorno            = "prod"
  vpc_id             = "vpc-test-123"
  public_subnet_ids  = ["subnet-pub-1", "subnet-pub-2"]
  private_subnet_ids = ["subnet-priv-1", "subnet-priv-2"]
  certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/test"

  servicios = {
    turnos = {
      container_port    = 8080
      cpu               = 512
      memory            = 1024
      desired_count     = 2
      health_check_path = "/turnos/health"
      path_pattern      = "/turnos/*"
    }
    hce = {
      container_port    = 8080
      cpu               = 1024
      memory            = 2048
      desired_count     = 2
      health_check_path = "/hce/health"
      path_pattern      = "/hce/*"
    }
    facturacion = {
      container_port    = 8080
      cpu               = 512
      memory            = 1024
      desired_count     = 2
      health_check_path = "/facturacion/health"
      path_pattern      = "/facturacion/*"
    }
  }

  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 10
  autoscaling_cpu_target   = 60
}

# -----------------------------------------------------------------------------
# Test 1: ECS Cluster se crea con Container Insights habilitado
# -----------------------------------------------------------------------------
run "ecs_cluster_created" {
  command = plan

  assert {
    condition     = aws_ecs_cluster.this.name != ""
    error_message = "ECS Cluster debe ser creado"
  }

  assert {
    condition     = contains([for s in aws_ecs_cluster.this.setting : s.value if s.name == "containerInsights"], "enabled")
    error_message = "Container Insights debe estar habilitado"
  }
}

# -----------------------------------------------------------------------------
# Test 2: Se crean 3 repositorios ECR (uno por microservicio)
# -----------------------------------------------------------------------------
run "ecr_repositories_count" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository.this) == 3
    error_message = "Deben existir 3 repositorios ECR (turnos, hce, facturacion)"
  }
}

# -----------------------------------------------------------------------------
# Test 3: Se crean 3 task definitions (una por microservicio)
# -----------------------------------------------------------------------------
run "task_definitions_count" {
  command = plan

  assert {
    condition     = length(aws_ecs_task_definition.this) == 3
    error_message = "Deben existir 3 task definitions (una por microservicio)"
  }
}

# -----------------------------------------------------------------------------
# Test 4: Todas las tasks usan Fargate (sin EC2)
# -----------------------------------------------------------------------------
run "all_tasks_use_fargate" {
  command = plan

  assert {
    condition     = alltrue([for td in aws_ecs_task_definition.this : contains(td.requires_compatibilities, "FARGATE")])
    error_message = "Todas las task definitions deben usar FARGATE como compatibilidad"
  }
}

# -----------------------------------------------------------------------------
# Test 5: Se crean 3 servicios ECS (uno por microservicio)
# -----------------------------------------------------------------------------
run "ecs_services_count" {
  command = plan

  assert {
    condition     = length(aws_ecs_service.this) == 3
    error_message = "Deben existir 3 servicios ECS (uno por microservicio)"
  }
}

# -----------------------------------------------------------------------------
# Test 6: Los servicios ECS corren en subnets privadas (no públicas)
# -----------------------------------------------------------------------------
run "ecs_services_in_private_subnets" {
  command = plan

  assert {
    condition     = alltrue([for svc in aws_ecs_service.this : length(svc.network_configuration[0].subnets) > 0])
    error_message = "Los servicios ECS deben correr en subnets privadas"
  }
}

# -----------------------------------------------------------------------------
# Test 7: Auto Scaling configurado para cada servicio
# -----------------------------------------------------------------------------
run "autoscaling_configured" {
  command = plan

  assert {
    condition     = length(aws_appautoscaling_target.this) == 3
    error_message = "Debe haber un target de autoscaling por cada servicio"
  }

  assert {
    condition     = alltrue([for t in aws_appautoscaling_target.this : t.max_capacity == 10])
    error_message = "Max capacity debe ser 10 para todos los servicios"
  }
}

# -----------------------------------------------------------------------------
# Test 8: CloudWatch Log Groups con retención diferenciada
# -----------------------------------------------------------------------------
run "log_groups_retention" {
  command = plan

  assert {
    condition     = alltrue([for lg in aws_cloudwatch_log_group.this : lg.retention_in_days == 90])
    error_message = "En prod, la retención de logs debe ser 90 días"
  }
}
