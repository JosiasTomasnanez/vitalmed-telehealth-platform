variable "pais" {
  type = string
}

variable "entorno" {
  type = string
}

variable "colas" {
  description = "Colas SQS a crear. Cada una dispara su propia Lambda."
  type = map(object({
    visibility_timeout_seconds = number
    lambda_timeout_seconds     = number
    lambda_memory_mb           = number
  }))
  default = {
    procesamiento_recetas = {
      visibility_timeout_seconds = 60
      lambda_timeout_seconds     = 30
      lambda_memory_mb           = 256
    }
    notificaciones = {
      visibility_timeout_seconds = 30
      lambda_timeout_seconds     = 15
      lambda_memory_mb           = 128
    }
  }
}

variable "kms_key_arn" {
  description = "KMS key (de modules/data) para cifrar los mensajes en las colas"
  type        = string
}
