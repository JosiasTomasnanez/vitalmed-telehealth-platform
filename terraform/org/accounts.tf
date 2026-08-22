# -----------------------------------------------------------------------------
# Account Factory
# -----------------------------------------------------------------------------
# Crea una cuenta AWS real por cada combinación país x entorno, ubicada
# dentro de la OU de su país. Cada cuenta queda aislada: sin esta cuenta
# nadie puede ver/tocar recursos de otro país u otro entorno por accidente,
# ni siquiera con una política de IAM mal escrita (el borde de seguridad
# es la cuenta misma, no una regla).

locals {
  # Genera todas las combinaciones país x entorno, ej: "ar-prod", "ar-preprod"...
  cuentas_workload = {
    for pair in setproduct(var.paises, var.entornos) :
    "${pair[0]}-${pair[1]}" => {
      pais    = pair[0]
      entorno = pair[1]
    }
  }
}

resource "aws_organizations_account" "workload" {
  for_each = local.cuentas_workload

  name  = "tp-diplodevops-${each.key}"
  email = "aws-${each.key}+${var.email_alias_suffix}" # ej: aws-ar-prod+diplodevops@dominio.com
  # El sufijo "+" con alias de email permite tener 8 cuentas AWS
  # usando una única casilla de correo real (necesario para el TP).

  parent_id = aws_organizations_organizational_unit.pais[each.value.pais].id

  role_name = "OrganizationAccountAccessRole" # rol que asume la cuenta management para operar en esta cuenta

  tags = {
    Pais    = each.value.pais
    Entorno = each.value.entorno
  }

  # Evita que Terraform intente "destruir" la cuenta si se saca del state;
  # las cuentas AWS no se eliminan, solo se cierran desde la consola.
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
