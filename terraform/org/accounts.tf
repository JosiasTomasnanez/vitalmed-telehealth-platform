# -----------------------------------------------------------------------------
# Account Factory
# -----------------------------------------------------------------------------
# - 1 cuenta de PRODUCCIÓN por país (dentro de la OU de su país): mantiene
#   el aislamiento total entre países en el entorno que realmente importa
#   aislar (datos reales de pacientes).
# - 1 única cuenta de PREPRODUCCIÓN general (no por país): entorno de
#   pruebas compartido, sin distinción de país.
# - 1 cuenta shared para el state de Terraform y logging centralizado.

resource "aws_organizations_account" "prod" {
  for_each = toset(var.paises)

  name  = "tp-diplodevops-${each.value}-prod"
  email = "aws-${each.value}-prod+${var.email_alias_suffix}" # ej: aws-ar-prod+diplodevops@dominio.com
  # El sufijo "+" con alias de email permite tener varias cuentas AWS
  # usando una única casilla de correo real (necesario para el TP).

  parent_id = aws_organizations_organizational_unit.pais[each.value].id
  role_name = "OrganizationAccountAccessRole" # rol que asume la cuenta management para operar en esta cuenta

  tags = {
    Pais    = each.value
    Entorno = "prod"
  }

  # Evita que Terraform intente "destruir" la cuenta si se saca del state;
  # las cuentas AWS no se eliminan, solo se cierran desde la consola.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "preprod" {
  name      = "tp-diplodevops-preprod"
  email     = "aws-preprod+${var.email_alias_suffix}"
  parent_id = aws_organizations_organizational_unit.preprod.id
  role_name = "OrganizationAccountAccessRole"

  tags = {
    Entorno = "preprod"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "shared" {
  name      = "tp-diplodevops-shared"
  email     = "aws-shared+${var.email_alias_suffix}"
  parent_id = aws_organizations_organizational_unit.shared.id
  role_name = "OrganizationAccountAccessRole"

  tags = {
    Proposito = "state-backend-y-logging-centralizado"
  }

  lifecycle {
    prevent_destroy = true
  }
}
