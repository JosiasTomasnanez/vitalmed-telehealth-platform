locals {
  nombre = "${var.pais}-${var.entorno}"

  tags_comunes = {
    Pais    = var.pais
    Entorno = var.entorno
    Modulo  = "edge"
  }
}
