locals {
  nombre = "${var.pais}-${var.entorno}"
}

# -----------------------------------------------------------------------------
# KMS — una key propia por país+entorno. No se comparte una key entre países:
# es la garantía técnica de que, aunque alguien accediera al bucket/DB
# equivocado, no podría descifrar datos de otro país sin esta key específica.
# -----------------------------------------------------------------------------
resource "aws_kms_key" "this" {
  description             = "Key de cifrado para datos de ${local.nombre} (Aurora + S3)"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = { Pais = var.pais, Entorno = var.entorno }
}

resource "aws_kms_alias" "this" {
  name          = "alias/diplodevops-${local.nombre}"
  target_key_id = aws_kms_key.this.key_id
}
