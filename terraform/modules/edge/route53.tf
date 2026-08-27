data "aws_route53_zone" "selected" {
  name         = "miapp.com"
  private_zone = false
}

resource "aws_route53_record" "cloudfront_a" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.dominio
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_aaaa" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.dominio
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
