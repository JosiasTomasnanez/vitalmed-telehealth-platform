terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket       = "tp-diplodevops-tfstate-mgmt"
    key          = "environments/co/preprod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Proyecto = "diplodevops-tp"
      Pais     = "co"
      Entorno  = "preprod"
    }
  }
}

module "network" {
  source = "git::https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git//terraform/modules/network?ref=v1.0"

  pais    = "co"
  entorno = "preprod"

  vpc_cidr             = "10.31.0.0/16"
  public_subnet_cidrs  = ["10.31.0.0/24", "10.31.1.0/24"]
  private_subnet_cidrs = ["10.31.10.0/24", "10.31.11.0/24"]
  data_subnet_cidrs    = ["10.31.20.0/24", "10.31.21.0/24"]

  single_nat_gateway = true # preprod: 1 solo NAT (ahorro de costo)
}

module "edge_cert" {
  source = "git::https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git//terraform/modules/edge-cert?ref=v1.0"

  pais            = "co"
  entorno         = "preprod"
  dominio         = "preprod.co.miapp.com"
  zona_route53_id = var.zona_route53_id
}

module "compute" {
  source = "git::https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git//terraform/modules/compute?ref=v1.0"

  pais    = "co"
  entorno = "preprod"

  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  certificate_arn = module.edge_cert.certificate_arn
}

module "data" {
  source = "git::https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git//terraform/modules/data?ref=v1.0"

  pais    = "co"
  entorno = "preprod"

  vpc_id                = module.network.vpc_id
  data_subnet_ids       = module.network.data_subnet_ids
  ecs_security_group_id = module.compute.ecs_security_group_id
}

module "async" {
  source = "git::https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git//terraform/modules/async?ref=v1.0"

  pais        = "co"
  entorno     = "preprod"
  kms_key_arn = module.data.kms_key_arn
}

module "frontend_bucket" {
  source = "git::https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git//terraform/modules/frontend-bucket?ref=v1.0"

  pais    = "co"
  entorno = "preprod"
}

module "edge" {
  source = "git::https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git//terraform/modules/edge?ref=v1.0"

  pais    = "co"
  entorno = "preprod"

  dominio                              = "preprod.co.miapp.com"
  zona_route53_id                      = var.zona_route53_id
  alb_dns_name                         = module.compute.alb_dns_name
  frontend_bucket_regional_domain_name = module.frontend_bucket.bucket_regional_domain_name
  certificate_arn                      = module.edge_cert.certificate_arn
}

resource "aws_iam_role_policy" "ecs_task_permisos" {
  name = "acceso-datos-y-colas"
  role = split("/", module.compute.ecs_task_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = module.data.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = concat(
          [for arn in module.data.s3_bucket_arns : arn],
          [for arn in module.data.s3_bucket_arns : "${arn}/*"]
        )
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [for arn in module.async.queue_arns : arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = module.data.kms_key_arn
      },
      {
        Effect   = "Allow"
        Action   = ["chime:CreateMeeting", "chime:DeleteMeeting", "chime:CreateAttendee"]
        Resource = "*"
      },
    ]
  })
}
