locals {
  nombre = "${var.pais}-${var.entorno}"
}

# -----------------------------------------------------------------------------
# ECR — un repo por microservicio (turnos, hce, facturacion)
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "this" {
  for_each = var.servicios

  name                 = "diplodevops/${local.nombre}/${each.key}"
  image_tag_mutability = "IMMUTABLE" # evita pisar un tag ya desplegado (trazabilidad de qué versión corre en cada país)

  image_scanning_configuration {
    scan_on_push = true # escaneo de vulnerabilidades automático, clave para HCE (datos sensibles)
  }

  tags = {
    Pais     = var.pais
    Entorno  = var.entorno
    Servicio = each.key
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = var.servicios
  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar solo las últimas 15 imágenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}
