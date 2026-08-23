variable "pais" {
  type        = string
  description = "Código de país (ar, cl, co, mx)"
}

variable "entorno" {
  type        = string
  description = "prod o preprod"
}

variable "vpc_id" {
  type        = string
  description = "VPC donde desplegar (output del módulo network)"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subnets públicas para el ALB (output del módulo network)"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets privadas para las tasks de ECS Fargate (output del módulo network)"
}

variable "certificate_arn" {
  type        = string
  description = "ARN del certificado ACM para el listener HTTPS del ALB (creado en modules/edge)"
}

variable "servicios" {
  description = "Microservicios a desplegar en ECS. Cada uno se convierte en su propio repo ECR, task definition, servicio ECS y target group del ALB."
  type = map(object({
    container_port = number
    cpu            = number # unidades de CPU Fargate (256, 512, 1024...)
    memory         = number # MB de memoria Fargate
    desired_count  = number
    health_check_path = string
    path_pattern       = string # ej: "/turnos/*" — usado en la regla del ALB para rutear a este microservicio
  }))
  default = {
    turnos = {
      container_port     = 8080
      cpu                = 512
      memory             = 1024
      desired_count      = 2
      health_check_path  = "/turnos/health"
      path_pattern       = "/turnos/*"
    }
    hce = {
      container_port     = 8080
      cpu                = 1024
      memory             = 2048
      desired_count      = 2
      health_check_path  = "/hce/health"
      path_pattern       = "/hce/*"
    }
    facturacion = {
      container_port     = 8080
      cpu                = 512
      memory             = 1024
      desired_count      = 2
      health_check_path  = "/facturacion/health"
      path_pattern       = "/facturacion/*"
    }
  }
}

variable "autoscaling_min_capacity" {
  type    = number
  default = 2
}

variable "autoscaling_max_capacity" {
  type    = number
  default = 10
}

variable "autoscaling_cpu_target" {
  description = "% de uso de CPU objetivo para el autoscaling de cada servicio ECS"
  type        = number
  default     = 60
}
