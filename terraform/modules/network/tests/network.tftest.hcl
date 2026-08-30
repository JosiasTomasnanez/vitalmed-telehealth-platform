# =============================================================================
# Tests: Módulo Network — VPC, Subnets, NAT Gateway, Route Tables
# Requisito: Terraform >= 1.10.0 (terraform test integrado)
# Ejecución: ./scripts/run-tests-localstack.ps1
# =============================================================================

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}

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
# Test 1: VPC configurada correctamente
# -----------------------------------------------------------------------------
run "vpc_created" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == var.vpc_cidr
    error_message = "La VPC debe estar configurada con el CIDR correcto"
  }
}

# -----------------------------------------------------------------------------
# Test 2: Se crean subnets correctas
# -----------------------------------------------------------------------------
run "subnets_created" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Deben configurarse 2 subnets públicas"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Deben configurarse 2 subnets privadas"
  }

  assert {
    condition     = length(aws_subnet.data) == 2
    error_message = "Deben configurarse 2 subnets de datos"
  }
}

# -----------------------------------------------------------------------------
# Test 3: Tags comunes aplicados correctamente
# -----------------------------------------------------------------------------
run "tags_applied" {
  command = plan

  assert {
    condition     = aws_vpc.this.tags["Pais"] == "ar"
    error_message = "Tag Pais debe ser 'ar'"
  }

  assert {
    condition     = aws_vpc.this.tags["Entorno"] == "prod"
    error_message = "Tag Entorno debe ser 'prod'"
  }
}
