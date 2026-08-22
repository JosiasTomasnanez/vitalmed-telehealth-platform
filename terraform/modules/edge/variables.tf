variable "pais" {
  type = string
}

variable "entorno" {
  type = string
}

variable "dominio" {
  description = "Dominio completo para este país+entorno, ej: ar.miapp.com (prod) o preprod.ar.miapp.com"
  type        = string
}

variable "zona_route53_id" {
  description = "Hosted zone de Route 53 donde crear el registro (puede ser una zona compartida del dominio raíz, delegada por país)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS del ALB (output de modules/compute) — origin de CloudFront para tráfico de API"
  type        = string
}

variable "frontend_bucket_regional_domain_name" {
  description = "Dominio regional del bucket S3 que sirve el frontend estático (build de React/Angular/etc.)"
  type        = string
}

variable "certificate_arn" {
  description = "ARN del certificado ACM ya validado (output de modules/edge-cert)"
  type        = string
}

variable "waf_rate_limit" {
  description = "Máximo de requests por IP cada 5 minutos antes de bloquear (mitigación básica de DDoS/abuso)"
  type        = number
  default     = 2000
}
