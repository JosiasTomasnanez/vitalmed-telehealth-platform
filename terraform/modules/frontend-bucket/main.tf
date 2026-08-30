# -----------------------------------------------------------------------------
# Bucket privado (sin acceso público directo) — solo CloudFront puede leerlo,
# a través del Origin Access Control definido en modules/edge.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "frontend" {
  bucket = "diplodevops-${var.pais}-${var.entorno}-frontend"
  tags   = { Pais = var.pais, Entorno = var.entorno }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "SoloCloudFront"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = "arn:aws:cloudfront::*:distribution/*"
        }
      }
    }]
  })
}
