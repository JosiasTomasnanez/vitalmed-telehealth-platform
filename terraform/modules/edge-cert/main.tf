locals {
  nombre = "${var.pais}-${var.entorno}"
}

# -----------------------------------------------------------------------------
# ACM — certificado público, validado automáticamente por DNS.
# Al estar todo en us-east-1, el mismo certificado sirve tanto para el
# listener HTTPS del ALB como para CloudFront (CloudFront exige que el
# certificado exista en us-east-1, así que no hace falta provider alias).
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "this" {
  domain_name       = var.dominio
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Pais = var.pais, Entorno = var.entorno }
}

resource "aws_route53_record" "validacion" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.zona_route53_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validacion : r.fqdn]
}
