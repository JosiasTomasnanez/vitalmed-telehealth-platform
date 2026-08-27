# -----------------------------------------------------------------------------
# Security group: solo ECS puede hablarle a Aurora, en el puerto de Postgres
# -----------------------------------------------------------------------------
resource "aws_security_group" "aurora" {
  name   = "aurora-${local.nombre}"
  vpc_id = var.vpc_id

  ingress {
    description     = "Postgres solo desde las tasks de ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "aurora-${local.nombre}" }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-${local.nombre}"
  subnet_ids = var.data_subnet_ids
  tags       = { Pais = var.pais, Entorno = var.entorno }
}

# -----------------------------------------------------------------------------
# Credenciales — password autogenerado y guardado en Secrets Manager,
# nunca en el state ni hardcodeado. ECS lo lee en runtime.
# -----------------------------------------------------------------------------
resource "random_password" "aurora_master" {
  length  = 32
  special = false # evita caracteres que compliquen la connection string
}

resource "aws_secretsmanager_secret" "aurora" {
  name       = "diplodevops/${local.nombre}/aurora-credentials"
  kms_key_id = aws_kms_key.this.key_id
}

resource "aws_secretsmanager_secret_version" "aurora" {
  secret_id = aws_secretsmanager_secret.aurora.id
  secret_string = jsonencode({
    username = var.aurora_master_username
    password = random_password.aurora_master.result
    dbname   = var.aurora_database_name
    host     = aws_rds_cluster.this.endpoint
    port     = 5432
  })
}

# -----------------------------------------------------------------------------
# Aurora Serverless v2 (Postgres) — escala automáticamente entre
# aurora_min_acu y aurora_max_acu según demanda, sin aprovisionar
# instancias fijas. Encaja bien con tráfico variable por país.
# -----------------------------------------------------------------------------
resource "aws_rds_cluster" "this" {
  cluster_identifier = "aurora-${local.nombre}"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned" # modo requerido para Serverless v2
  engine_version     = "15.4"

  database_name   = var.aurora_database_name
  master_username = var.aurora_master_username
  master_password = random_password.aurora_master.result

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  storage_encrypted = true
  kms_key_id        = aws_kms_key.this.arn

  backup_retention_period   = var.backup_retention_days
  preferred_backup_window   = "03:00-04:00"
  copy_tags_to_snapshot     = true
  deletion_protection       = var.entorno == "prod" ? true : false
  skip_final_snapshot       = var.entorno == "prod" ? false : true
  final_snapshot_identifier = var.entorno == "prod" ? "aurora-${local.nombre}-final" : null

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_acu
    max_capacity = var.aurora_max_acu
  }

  enabled_cloudwatch_logs_exports = ["postgresql"] # necesario para trazabilidad de accesos a HCE

  tags = { Pais = var.pais, Entorno = var.entorno }
}

resource "aws_rds_cluster_instance" "this" {
  count              = var.entorno == "prod" ? 2 : 1 # prod: 1 writer + 1 reader; preprod: solo writer
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  tags = { Pais = var.pais, Entorno = var.entorno }
}
