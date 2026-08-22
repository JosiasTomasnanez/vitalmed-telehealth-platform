# -----------------------------------------------------------------------------
# S3 — un bucket por tipo de contenido (estudios médicos, adjuntos de
# facturación), cifrado con la KMS key propia del país+entorno, versionado
# y con acceso público bloqueado por completo.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  for_each = toset(var.s3_buckets)
  bucket   = "diplodevops-${local.nombre}-${each.value}"

  tags = { Pais = var.pais, Entorno = var.entorno, Contenido = each.value }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled" # protege contra borrado/sobreescritura accidental de estudios médicos
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true # reduce costo de llamadas a KMS
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id

  rule {
    id     = "transicion-a-infrequent-access"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}
