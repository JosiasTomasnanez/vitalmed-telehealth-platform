variable "account_id" {
  description = "Account ID de la cuenta AWS ar-prod (obtenido del output account_ids del stack /org)"
  type        = string
}

variable "zona_route53_id" {
  description = "Hosted zone de Route 53 (zona del dominio raíz, ej: miapp.com) donde se crean los registros de este país+entorno"
  type        = string
}
