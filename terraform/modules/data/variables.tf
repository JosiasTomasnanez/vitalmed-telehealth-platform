variable "pais" {
  type = string
}

variable "entorno" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "data_subnet_ids" {
  type        = list(string)
  description = "Subnets sin salida a Internet (output del módulo network)"
}

variable "ecs_security_group_id" {
  type        = string
  description = "Security group de ECS — único origen permitido hacia Aurora"
}

variable "aurora_min_acu" {
  description = "Capacidad mínima en Aurora Capacity Units. 0.5 permite escalar a casi cero en preprod cuando no hay tráfico"
  type        = number
  default     = 0.5
}

variable "aurora_max_acu" {
  type    = number
  default = 4
}

variable "aurora_database_name" {
  type    = string
  default = "hce"
}

variable "aurora_master_username" {
  type    = string
  default = "hce_admin"
}

variable "s3_buckets" {
  description = "Buckets S3 a crear para estudios/adjuntos médicos, todos cifrados con la KMS key propia del país+entorno"
  type        = list(string)
  default     = ["estudios-medicos", "adjuntos-facturacion"]
}

variable "backup_retention_days" {
  type    = number
  default = 7
}
