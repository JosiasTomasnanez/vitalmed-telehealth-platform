# =============================================================================
# Tests: Módulo Network — VPC, Subnets, NAT Gateway, Route Tables
# Requisito: Terraform >= 1.10.0 (terraform test integrado)
# Ejecución: ./scripts/run-tests-localstack.ps1
# =============================================================================

variables {
  pais                 = "ar"
  entorno              = "prod"
  vpc_cidr             = "10.10.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
  private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]
  data_subnet_cidrs    = ["10.10.20.0/24", "10.10.21.0/24"]
  single_nat_gateway   = false
}

# -----------------------------------------------------------------------------
# Test 1: VPC se crea correctamente
# -----------------------------------------------------------------------------
run "vpc_created" {
  command = apply

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC debe ser creada y devolver un ID válido"
  }
}

# -----------------------------------------------------------------------------
# Test 2: Se crean subnets correctas
# -----------------------------------------------------------------------------
run "subnets_created" {
  command = apply

  assert {
    condition     = length(output.public_subnet_ids) == 2
    error_message = "Deben existir 2 subnets públicas"
  }

  assert {
    condition     = length(output.private_subnet_ids) == 2
    error_message = "Deben existir 2 subnets privadas"
  }

  assert {
    condition     = length(output.data_subnet_ids) == 2
    error_message = "Deben existir 2 subnets de datos"
  }
}

# -----------------------------------------------------------------------------
# Test 3: Tags comunes aplicados correctamente
# -----------------------------------------------------------------------------
run "tags_applied" {
  command = apply

  assert {
    condition     = aws_vpc.this.tags["Pais"] == "ar"
    error_message = "Tag Pais debe ser 'ar'"
  }

  assert {
    condition     = aws_vpc.this.tags["Entorno"] == "prod"
    error_message = "Tag Entorno debe ser 'prod'"
  }
}
