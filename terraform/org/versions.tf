terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend de estado dedicado para la cuenta de management.
  # Ver /global/state-backend para el bootstrap del bucket S3.
  backend "s3" {
    bucket         = "tp-diplodevops-tfstate-mgmt"
    key            = "org/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"

  # Se asume que las credenciales usadas para aplicar este stack
  # pertenecen a la cuenta de management de la Organization.
  default_tags {
    tags = {
      Proyecto  = "diplodevops-tp"
      GestionadoPor = "terraform"
      Capa      = "organizations"
    }
  }
}
