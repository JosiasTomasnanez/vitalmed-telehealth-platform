locals {
  nombre = "${var.pais}-${var.entorno}"
}

# -----------------------------------------------------------------------------
# SQS — una cola principal + una dead-letter queue (DLQ) por caso de uso.
# La DLQ evita que un mensaje con error (ej: una receta mal formada)
# reintente infinitamente y tape la cola principal.
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "dlq" {
  for_each                  = var.colas
  name                      = "diplodevops-${local.nombre}-${each.key}-dlq"
  message_retention_seconds = 1209600 # 14 días — tiempo para investigar el error
  kms_master_key_id         = var.kms_key_arn

  tags = { Pais = var.pais, Entorno = var.entorno }
}

resource "aws_sqs_queue" "this" {
  for_each                   = var.colas
  name                       = "diplodevops-${local.nombre}-${each.key}"
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  kms_master_key_id          = var.kms_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 3
  })

  tags = { Pais = var.pais, Entorno = var.entorno }
}
