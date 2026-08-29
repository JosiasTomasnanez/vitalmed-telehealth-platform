# -----------------------------------------------------------------------------
# AWS Organizations
# -----------------------------------------------------------------------------
# Habilita la Organization en la cuenta de management. Si la cuenta ya
# pertenece a una Organization (por ejemplo, creada a mano para el TP),
# este recurso se importa en lugar de crearse (terraform import).

resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com", # IAM Identity Center
  ]

  feature_set = "ALL" # requerido para SCPs y para IAM Identity Center
}

# -----------------------------------------------------------------------------
# Organizational Units
# -----------------------------------------------------------------------------
# Estructura: raíz -> Workloads -> <país> -> <entorno>
# Esto permite aplicar SCPs (documentadas, no codeadas acá) a nivel país
# o a nivel entorno según se necesite.

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "pais" {
  for_each  = toset(var.paises)
  name      = each.value
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# Preprod ya no se organiza por país: es una única OU general que aloja
# la cuenta de preproducción compartida entre todos los países.
resource "aws_organizations_organizational_unit" "preprod" {
  name      = "Preprod"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "shared" {
  name      = "Shared"
  parent_id = aws_organizations_organization.this.roots[0].id
}
