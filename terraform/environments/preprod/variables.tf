variable "account_id" {
  description = "Account ID de la única cuenta AWS de preproducción (obtenido del output preprod_account_id del stack /org)"
  type        = string
}

variable "zona_route53_id" {
  description = "Hosted zone de Route 53 (zona del dominio raíz) donde se crea el registro de este entorno"
  type        = string
}
