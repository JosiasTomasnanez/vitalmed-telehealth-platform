output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.this.endpoint
}

output "aurora_secret_arn" {
  description = "ARN del secret en Secrets Manager con las credenciales de Aurora — se le da permiso de lectura al task_role de ECS"
  value       = aws_secretsmanager_secret.aurora.arn
}

output "kms_key_arn" {
  value = aws_kms_key.this.arn
}

output "s3_bucket_names" {
  value = { for k, v in aws_s3_bucket.this : k => v.bucket }
}

output "s3_bucket_arns" {
  value = { for k, v in aws_s3_bucket.this : k => v.arn }
}
