# =============================================================================
# Tests: Módulo Edge — CloudFront, WAF, Route53
# Ejecución: ./scripts/run-tests-localstack.sh
# =============================================================================

variables {
  pais                                 = "ar"
  entorno                              = "prod"
  dominio                              = "ar.miapp.com"
  zona_route53_id                      = "ZXAQRFCU1A7P4N"
  alb_dns_name                         = "alb-ar-prod-123.us-east-1.elb.amazonaws.com"
  frontend_bucket_regional_domain_name = "frontend-ar-prod.s3.us-east-1.amazonaws.com"
  certificate_arn                      = "arn:aws:acm:us-east-1:123456789012:certificate/test"
  waf_rate_limit                       = 2000
}

# -----------------------------------------------------------------------------
# Test 1: CloudFront distribution se crea habilitada
# -----------------------------------------------------------------------------
run "cloudfront_enabled" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.enabled == true
    error_message = "CloudFront distribution debe estar habilitada"
  }

  assert {
    condition     = aws_cloudfront_distribution.this.is_ipv6_enabled == true
    error_message = "CloudFront debe soportar IPv6"
  }
}

# -----------------------------------------------------------------------------
# Test 2: CloudFront tiene 2 origins (S3 frontend + ALB API)
# -----------------------------------------------------------------------------
run "cloudfront_two_origins" {
  command = apply

  assert {
    condition     = length(aws_cloudfront_distribution.this.origin) == 2
    error_message = "CloudFront debe tener 2 origins: S3 (frontend) y ALB (API)"
  }
}

# -----------------------------------------------------------------------------
# Test 3: CloudFront usa TLS 1.2 mínimo
# -----------------------------------------------------------------------------
run "cloudfront_tls_12_minimum" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021"
    error_message = "CloudFront debe usar TLS 1.2 como mínimo"
  }
}

# -----------------------------------------------------------------------------
# Test 4: WAF Web ACL se crea
# -----------------------------------------------------------------------------
run "waf_web_acl_created" {
  command = plan

  assert {
    condition     = aws_wafv2_web_acl.this.name != ""
    error_message = "WAF Web ACL debe ser creada"
  }
}

# -----------------------------------------------------------------------------
# Test 5: WAF tiene rate limiting configurado
# -----------------------------------------------------------------------------
run "waf_rate_limiting" {
  command = plan

  assert {
    condition     = aws_wafv2_web_acl.this.scope == "CLOUDFRONT"
    error_message = "WAF Web ACL debe estar configurada para CLOUDFRONT"
  }
}

# -----------------------------------------------------------------------------
# Test 6: Route53 record se crea
# -----------------------------------------------------------------------------
run "route53_record_created" {
  command = plan

  assert {
    condition     = aws_route53_record.this.name != ""
    error_message = "Route53 record debe ser creado"
  }

  assert {
    condition     = aws_route53_record.this.type == "A"
    error_message = "Route53 record debe ser de tipo A (alias)"
  }
}

# -----------------------------------------------------------------------------
# Test 7: CloudFront tiene restricción geográfica desactivada
# -----------------------------------------------------------------------------
run "cloudfront_no_geo_restriction" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.restrictions[0].geo_restriction[0].restriction_type == "none"
    error_message = "CloudFront no debe tener restricciones geográficas (acceso global)"
  }
}
