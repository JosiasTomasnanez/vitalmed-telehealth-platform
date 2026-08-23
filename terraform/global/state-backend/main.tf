# -----------------------------------------------------------------------------
# Bootstrap del backend de Terraform.
#
# Este stack se aplica UNA sola vez, con backend local (no remoto, porque
# todavía no existe el bucket), y antes que cualquier otro stack del repo.
# Después de aplicarlo, todos los demás módulos (org, environments/*) usan
# este bucket como backend "s3" remoto, con locking nativo del bucket
# (use_lockfile = true, disponible desde Terraform 1.10).
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Backend local a propósito: bootstrap.
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "tp-diplodevops-tfstate-mgmt"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled" # permite recuperar un state anterior si algo sale mal
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
