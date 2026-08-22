# -----------------------------------------------------------------------------
# WAF — WebACL con reglas administradas de AWS (protección genérica contra
# OWASP Top 10, bots conocidos) más una regla de rate limiting propia.
# Se asocia a CloudFront, por eso el scope es CLOUDFRONT (siempre en us-east-1).
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "this" {
  name  = "waf-${local.nombre}"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-managed-common"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rule-set-${local.nombre}"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "bad-inputs-${local.nombre}"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit-por-ip"
    priority = 3
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-${local.nombre}"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-${local.nombre}"
    sampled_requests_enabled   = true
  }

  tags = { Pais = var.pais, Entorno = var.entorno }
}
