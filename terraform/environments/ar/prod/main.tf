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
    key          = "environments/ar/prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "us-east-1"

  # Terraform asume el rol OrganizationAccountAccessRole dentro de la
  # cuenta AWS específica de ar-prod (creada por /org). El account_id
  # sale del output de ese stack (o se referencia con terraform_remote_state).
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Proyecto = "diplodevops-tp"
      Pais     = "ar"
      Entorno  = "prod"
    }
  }
}

module "network" {
  source = "D:/Archivos de programa D/GDrive/vitalmed-telehealth-platform/terraform/modules/network"

  pais    = "ar"
  entorno = "prod"

  vpc_cidr             = "10.10.0.0/16"
  public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
  private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]
  data_subnet_cidrs    = ["10.10.20.0/24", "10.10.21.0/24"]

  single_nat_gateway = false # prod: alta disponibilidad, 1 NAT por AZ
}

module "edge_cert" {
  source = "D:/Archivos de programa D/GDrive/vitalmed-telehealth-platform/terraform/modules/edge-cert"

  pais            = "ar"
  entorno         = "prod"
  dominio         = "ar.miapp.com"
  zona_route53_id = var.zona_route53_id
}

module "compute" {
  source = "D:/Archivos de programa D/GDrive/vitalmed-telehealth-platform/terraform/modules/compute"

  pais    = "ar"
  entorno = "prod"

  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  certificate_arn = module.edge_cert.certificate_arn
}

module "data" {
  source = "D:/Archivos de programa D/GDrive/vitalmed-telehealth-platform/terraform/modules/data"

  pais    = "ar"
  entorno = "prod"

  vpc_id                = module.network.vpc_id
  data_subnet_ids       = module.network.data_subnet_ids
  ecs_security_group_id = module.compute.ecs_security_group_id
}

module "async" {
  source = "D:/Archivos de programa D/GDrive/vitalmed-telehealth-platform/terraform/modules/async"

  pais        = "ar"
  entorno     = "prod"
  kms_key_arn = module.data.kms_key_arn
}

module "edge" {
  source = "D:/Archivos de programa D/GDrive/vitalmed-telehealth-platform/terraform/modules/edge"

  pais    = "ar"
  entorno = "prod"

  dominio                              = "ar.miapp.com"
  zona_route53_id                      = var.zona_route53_id
  alb_dns_name                         = module.compute.alb_dns_name
  frontend_bucket_regional_domain_name = module.frontend_bucket.bucket_regional_domain_name
  certificate_arn                      = module.edge_cert.certificate_arn
}

# Bucket S3 aparte para el build estático del frontend (no lleva datos de
# pacientes, por eso no vive en modules/data junto a estudios/adjuntos).
module "frontend_bucket" {
  source = "D:/Archivos de programa D/GDrive/vitalmed-telehealth-platform/terraform/modules/frontend-bucket"

  pais    = "ar"
  entorno = "prod"
}

# -----------------------------------------------------------------------------
# Permisos del task role de ECS hacia los recursos de datos y async,
# resueltos acá porque solo el root module conoce ambos lados.
# -----------------------------------------------------------------------------
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
        # Permiso para que el backend cree/gestione videollamadas con Chime SDK.
        # Ver README: Chime SDK no tiene recursos declarativos, solo este permiso IAM.
        Effect   = "Allow"
        Action   = ["chime:CreateMeeting", "chime:DeleteMeeting", "chime:CreateAttendee"]
        Resource = "*"
      },
    ]
  })
}
