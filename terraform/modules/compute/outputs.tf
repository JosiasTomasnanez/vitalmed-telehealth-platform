output "alb_dns_name" {
  description = "DNS del ALB — usado como origin en CloudFront (modules/edge)"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecr_repository_urls" {
  description = "Mapa servicio => URL del repo ECR, para que el pipeline de CI/CD sepa a dónde pushear las imágenes"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "ecs_task_role_arn" {
  description = "ARN del task role — el módulo raíz del environment le adjunta acá los permisos hacia Aurora/S3/SQS/Chime"
  value       = aws_iam_role.task.arn
}

output "ecs_security_group_id" {
  description = "Security group de las tasks — usado por modules/data para permitir ingreso a Aurora solo desde ECS"
  value       = aws_security_group.ecs_tasks.id
}
