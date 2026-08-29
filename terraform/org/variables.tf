variable "paises" {
  description = "Códigos de país donde se despliega la aplicación en producción"
  type        = list(string)
  default     = ["ar", "cl", "co", "mx"]
}

variable "email_alias_suffix" {
  description = "Parte del email real después del '+' usada como alias para todas las cuentas AWS (ej: tuusuario@dominio.com)"
  type        = string
}
