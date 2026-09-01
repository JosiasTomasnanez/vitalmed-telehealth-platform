# Runbook de Operaciones — Anexo (VitalMed Telesalud)

**Grupo 9 · Diplomatura DevOps · Pilar: Excelencia Operativa**

> Anexo del [Runbook de Despliegue](./runbook.md). Reúne el material operativo de referencia (comandos rápidos, naming, tagging, monitoreo, backup, incident response, troubleshooting, colaboración, onboarding y contactos), antes secciones 9–18 del runbook principal.
>
> **Nota**: CloudTrail, GuardDuty, X-Ray, Security Hub y VPC Flow Logs están **"solo diseño"** (ver runbook §8.4). Los comandos que los usan aquí requieren cuenta real y servicios aún no provisionados por el Terraform.

---

## 1. Comandos Rápidos de Referencia

```bash
# Formatear código
terraform fmt -recursive

# Validar todos los entornos
for dir in terraform/environments/*/*/; do
  [ -f "$dir/main.tf" ] && (cd "$dir" && terraform init -backend=false && terraform validate)
done

# Ejecutar todos los tests
for module_dir in terraform/modules/*/; do
  [ -d "${module_dir}tests" ] && (cd "$module_dir" && terraform test)
done

# Ver estado de un entorno
cd terraform/environments/ar/prod
terraform state list
terraform state show aws_ecs_cluster.this

# Importar un recurso existente
terraform import aws_vpc.existing vpc-12345678

# Destruir un entorno (¡CUIDADO!)
terraform destroy -target=module.compute
```

---

## 2. Naming Conventions (Convenciones de Nombres)

### 2.1 Estructura de Nombres

```
<pais>-<entorno>-<servicio>-<recurso>
```

| Componente | Valores | Ejemplo |
|------------|---------|---------|
| `pais` | `ar`, `cl`, `co`, `mx` | `ar` |
| `entorno` | `prod`, `preprod` | `prod` |
| `servicio` | `ecs`, `aurora`, `s3`, `sqs`, `lambda`, `alb`, `cf`, `waf` | `ecs` |
| `recurso` | Descriptivo | `turnos`, `pagos` |

### 2.2 Nombres Reales por Recurso

Los nombres son los que genera el código (`local.nombre = {pais}-{entorno}`, ej. `ar-prod`). Úsese esta tabla como fuente de verdad:

| Recurso | Patrón real | Ejemplo |
|---------|-------------|---------|
| VPC | `vpc-{pais}-{entorno}` | `vpc-ar-prod` |
| Subnets | `sn-{pub,priv,data}-{pais}-{entorno}-{az}` | `sn-pub-ar-prod-us-east-1a` |
| Internet Gateway | `igw-{pais}-{entorno}` | `igw-ar-prod` |
| NAT Gateway | `nat-{pais}-{entorno}-{i}` | `nat-ar-prod-0` |
| Route tables | `rt-{pub,priv,data}-{pais}-{entorno}[-{az}]` | `rt-data-ar-prod` |
| ALB | `alb-{pais}-{entorno}` | `alb-ar-prod` |
| Security Groups | `sg-{alb,ecs,aurora}-{pais}-{entorno}` | `sg-ecs-ar-prod` |
| ECS Cluster | `ecs-{pais}-{entorno}` | `ecs-ar-prod` |
| ECS Service / Task family | `{pais}-{entorno}-{servicio}` | `ar-prod-turnos` |
| ECR Repository | `diplodevops/{pais}-{entorno}/{servicio}` | `diplodevops/ar-prod/turnos` |
| Aurora Cluster | `aurora-{pais}-{entorno}` | `aurora-ar-prod` |
| S3 Buckets (datos) | `diplodevops-{pais}-{entorno}-{tipo}` | `diplodevops-ar-prod-estudios-medicos` |
| S3 Bucket (frontend) | `diplodevops-{pais}-{entorno}-frontend` | `diplodevops-ar-prod-frontend` |
| SQS Queue (+DLQ) | `diplodevops-{pais}-{entorno}-{cola}` / `-dlq` | `diplodevops-ar-prod-procesamiento_recetas` |
| Lambda Function | `diplodevops-{pais}-{entorno}-{fn}` | `diplodevops-ar-prod-procesamiento_recetas` |
| KMS Alias | `alias/diplodevops-{pais}-{entorno}` | `alias/diplodevops-ar-prod` |
| Secret (Aurora) | `diplodevops/{pais}-{entorno}/aurora-credentials` | `diplodevops/ar-prod/aurora-credentials` |
| Log Group | `/ecs/{pais}-{entorno}/{servicio}` | `/ecs/ar-prod/turnos` |
| CloudFront / WAF | sin nombre explícito (auto-generado) | — |

### 2.3 Reglas de Formato

- **Minúsculas**: todos los nombres en minúsculas.
- **Guiones** como separador (`-`), salvo en rutas tipo `diplodevops/ar-prod/turnos` (ECR, Secret) que usan `/`.
- **Prefijos estándar**: `vpc-`, `sn-`, `igw-`, `nat-`, `rt-`, `alb-`, `sg-`, `ecs-`, `aurora-`.
- **Namespace global** `diplodevops-` (o `diplodevops/`) para recursos cuyo nombre debe ser único a nivel de cuenta (S3, SQS, Lambda, ECR, KMS, Secret).
- **Longitud máxima**: 63 caracteres (límite de AWS).

> **Excepción conocida**: las colas SQS y funciones Lambda usan guión bajo en `procesamiento_recetas` (y `notificaciones`), lo que contradice la regla de "solo guiones". Es un defecto del código actual, no del runbook — está pendiente de normalizar en un PR de Terraform futuro.

---

## 3. Tagging Strategy (Estrategia de Tags)

### 3.1 Tags Aplicados Hoy

El código aplica estos tags (via `default_tags` del provider y tags por recurso):

| Tag | Origen | Valores |
|-----|-------------|---------|
| `Proyecto` | `default_tags` (provider) | `diplodevops-tp` |
| `Pais` | `default_tags` + recurso | `ar`, `cl`, `co`, `mx`, `global` (preprod) |
| `Entorno` | `default_tags` + recurso | `prod`, `preprod` |
| `Tier` | módulo `network` | `public`, `private`, `data` |
| `Servicio` | módulo `compute` (ECR) | `turnos`, `hce`, `facturacion` |

### 3.2 Tags Propuestos a Futuro

| Tag | Descripción | Ejemplo |
|-----|-------------|---------|
| `ManagedBy` | Herramienta de gestión | `terraform` |
| `Owner` | Responsable del recurso | `equipo-devops` |
| `Criticality` | Nivel de criticidad | `high`, `medium`, `low` |
| `Backup` | Política de backup | `daily`, `weekly`, `none` |

### 3.3 Implementación en Terraform

```hcl
# Provider con tags globales (así está hoy en cada environment)
provider "aws" {
  # ...
  default_tags {
    tags = {
      Proyecto = "diplodevops-tp"
      Pais     = var.pais
      Entorno  = var.entorno
    }
  }
}

# Tags por recurso
resource "aws_ecs_cluster" "this" {
  name = "ecs-${local.nombre}"

  tags = { Pais = var.pais, Entorno = var.entorno }
}
```

### 3.4 Validación de Tags

```bash
# Verificar que los recursos tienen los tags Pais y Entorno
aws ec2 describe-instances \
  --filters "Name=tag:Proyecto,Values=diplodevops-tp" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Pais`].Value|[0],Tags[?Key==`Entorno`].Value|[0]]' \
  --output table

# Recursos sin tag Pais
aws ec2 describe-instances \
  --filters "Name=tag:Proyecto,Values=diplodevops-tp" \
  --query 'Reservations[*].Instances[?!Tags[?Key==`Pais`]].InstanceId' \
  --output text
```

---

## 4. Monitoreo y Alertas

> **Material de referencia**: las alarmas, dashboard y SNS de esta sección **no están en el código Terraform actual** (CloudWatch está parcialmente codeado: log groups y Container Insights en `modules/compute`). Son la guía para implementar el monitoreo completo al desplegar en cuenta real.

### 4.1 Métricas Clave a Monitorear

| Servicio | Métrica | Umbral | Acción |
|----------|---------|--------|--------|
| **ECS** | CPUUtilization | > 80% por 5 min | Escalar tareas |
| **ECS** | MemoryUtilization | > 80% por 5 min | Escalar tareas |
| **ECS** | TaskCount | < desired | Investigar tasks fallidas |
| **Aurora** | DatabaseConnections | > 80% max | Escalar ACUs |
| **Aurora** | CPUUtilization | > 70% por 10 min | Escalar ACUs |
| **Aurora** | ServerlessDatabaseCapacity | > 4 ACUs | Revisar queries |
| **ALB** | TargetResponseTime | > 2s por 5 min | Investigar latencia |
| **ALB** | HTTPCode_5XX_Count | > 10 por 5 min | Revisar logs |
| **ALB** | HealthyHostCount | < 2 | Investigar health checks |
| **S3** | 4xxErrors | > 100 por hora | Revisar permisos |
| **SQS** | ApproximateAgeOfOldestMessage | > 300s | Investigar consumers |
| **Lambda** | Errors | > 5 por 5 min | Revisar logs |
| **Lambda** | Duration | > 80% timeout | Aumentar timeout |

### 4.2 Alarmas de CloudWatch

```hcl
# Alarma de ECS - CPU Alta
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = var.servicios

  alarm_name          = "ecs-${local.nombre}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU alta en ECS ${each.key}"

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this[each.key].name
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
  ok_actions    = [aws_sns_topic.alertas.arn]
}

# Alarma de Aurora - Conexiones Altas
resource "aws_cloudwatch_metric_alarm" "aurora_connections_high" {
  alarm_name          = "aurora-${local.nombre}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Conexiones altas en Aurora"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.id
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
}

# Alarma de ALB - Errores 5XX
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "alb-${local.nombre}-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Errores 5XX altos en ALB"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
}

# Alarma de SQS - Mensajes Estancados
resource "aws_cloudwatch_metric_alarm" "sqs_old_messages" {
  for_each = var.colas

  alarm_name          = "sqs-${local.nombre}-${each.key}-old-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 300
  alarm_description   = "Mensajes estancados en cola ${each.key}"

  dimensions = {
    QueueName = aws_sqs_queue.this[each.key].name
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
}
```

### 4.3 Dashboard de CloudWatch

```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "vitalmed-${local.nombre}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", "ecs-${local.nombre}", "ServiceName", "turnos"],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", "ecs-${local.nombre}", "ServiceName", "turnos"]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "ECS - CPU & Memory"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "aurora-${local.nombre}"],
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", "aurora-${local.nombre}"]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Aurora - Conexiones & CPU"
        }
      }
    ]
  })
}
```

### 4.4 SNS Topics para Alertas

```hcl
resource "aws_sns_topic" "alertas" {
  name = "alertas-${local.nombre}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "email"
  endpoint  = var.alerta_email
}

resource "aws_sns_topic_subscription" "slack" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notify[0].arn
}
```

---

## 5. Backup y Recovery

### 5.1 Backup de Estado de Terraform

```bash
# Backup manual del estado
aws s3api copy-object \
  --bucket tp-diplodevops-tfstate-mgmt \
  --copy-source tp-diplodevops-tfstate-mgmt/environments/ar/prod/terraform.tfstate \
  --key "environments/ar/prod/terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)"

# Listar versiones del estado
aws s3api list-object-versions \
  --bucket tp-diplodevops-tfstate-mgmt \
  --prefix environments/ar/prod/terraform.tfstate \
  --query 'Versions[*].[VersionId,LastModified,Size]' \
  --output table

# Restaurar versión específica
aws s3api get-object \
  --bucket tp-diplodevops-tfstate-mgmt \
  --key environments/ar/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.restored
```

### 5.2 Backup de Aurora

```hcl
# Backup automático (configurado en Aurora)
resource "aws_rds_cluster" "this" {
  # ...

  backup_retention_period      = 7  # días
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  final_snapshot_identifier    = "final-${local.nombre}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  skip_final_snapshot         = false
}

# Snapshot manual
# aws rds create-db-cluster-snapshot \
#   --db-cluster-identifier aurora-ar-prod \
#   --db-cluster-snapshot-identifier manual-$(date +%Y%m%d)
```

### 5.3 Backup de S3

```hcl
# Habilitar versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle para mover a Glacier
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "move-to-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
```

### 5.4 Procedimiento de Recovery

```bash
# 1. Detener despliegues: desactivar el workflow o proteger main (ver runbook §6.3)

# 2. Restaurar estado de Terraform
cd terraform/environments/ar/prod
aws s3api get-object \
  --bucket tp-diplodevops-tfstate-mgmt \
  --key environments/ar/prod/terraform.tfstate \
  --version-id <LAST_GOOD_VERSION> \
  terraform.tfstate
terraform state push terraform.tfstate

# 3. Verificar estado
terraform state list
terraform plan

# 4. Restaurar Aurora (si es necesario)
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier aurora-ar-prod-restored \
  --snapshot-identifier <SNAPSHOT_ID> \
  --engine aurora-postgresql

# 5. Restaurar S3 (si es necesario)
aws s3api list-object-versions \
  --bucket diplodevops-ar-prod-estudios-medicos \
  --prefix <PATH> \
  --query 'Versions[0].VersionId' \
  --output text
# Luego usar version-id para restaurar

# 6. Verificar restauración
# ... tests de conectividad ...

# 7. Des-congelar despliegues: re-habilitar el workflow / quitar la protección
```

---

## 6. Seguridad - Incident Response

### 6.1 Tipos de Incidentes

| Severidad | Descripción | Ejemplo |
|-----------|-------------|---------|
| **P1 - Crítico** | Riesgo de datos o servicio caído | Breach de seguridad, Aurora caído |
| **P2 - Alto** | Degradación significativa | ALB con errores, latencia alta |
| **P3 - Medio** | Issue menor | Log group lleno, métrica anómala |
| **P4 - Bajo** | Mejora o documentación | Optimización de costos |

### 6.2 Procedimiento de Respuesta

#### Paso 1: Detectar y Alertar

```bash
# Verificar alarmas activas
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --query 'MetricAlarms[*].[AlarmName,StateReason,AlarmDescription]' \
  --output table

# Verificar logs de error
aws logs filter-log-events \
  --log-group-name /ecs/ar-prod/turnos \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --query 'events[*].[timestamp,message]' \
  --output table
```

#### Paso 2: Contener

```bash
# Si es un issue de ECS, forzar redeployment
aws ecs update-service \
  --cluster ecs-ar-prod \
  --service turnos \
  --force-new-deployment

# Si es un issue de Aurora, reboot
aws rds reboot-db-cluster \
  --db-cluster-identifier aurora-ar-prod

# Si es un breach de seguridad, bloquear IP
aws ec2 create-security-group \
  --group-name blocked-ips \
  --description "IPs bloqueadas"
# Luego agregar reglas de bloqueo
```

#### Paso 3: Investigar

```bash
# CloudTrail - Últimas acciones (solo diseño, ver runbook §8.4)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --query 'Events[*].[EventTime,Username,EventName,SourceIPAddress]' \
  --output table

# GuardDuty - Hallazgos (solo diseño, ver runbook §8.4)
aws guardduty list-findings \
  --finding-criteria '{"Criterion": {"severity": {"Gte": 7}}}' \
  --query 'FindingIds' \
  --output text

# VPC Flow Logs - Tráfico sospechoso (solo diseño, ver runbook §8.4)
aws logs filter-log-events \
  --log-group-name vpc-flow-logs-ar-prod \
  --filter-pattern "REJECT" \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --query 'events[*].[timestamp,message]' \
  --output table
```

#### Paso 4: Remediar

```bash
# Rotar credenciales expuestas
aws secretsmanager rotate-secret \
  --secret-id diplodevops/ar-prod/aurora-credentials

# Actualizar security groups
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 10.0.0.0/8

# Aplicar parches de Terraform
cd terraform/environments/ar/prod
terraform plan -out=tfplan
terraform apply tfplan
```

#### Paso 5: Documentar

Crear incidente con:
- **Fecha/hora** del incidente
- **Severidad** (P1-P4)
- **Servicio afectado**
- **Causa raíz**
- **Acciones tomadas**
- **Tiempo de resolución**
- **Lecciones aprendidas**

### 6.3 Playbooks Rápidos

| Incidente | Acción Inmediata |
|-----------|------------------|
| Aurora caído | `aws rds reboot-db-cluster` → Si no funciona, `restore-from-snapshot` |
| ECS service caído | `aws ecs update-service --force-new-deployment` |
| ALB 5XX alto | Revisar target groups,health checks,logs de backend |
| S3 bucket público | `aws s3api put-bucket-acl --acl private` |
| Credencial expuesta | `aws secretsmanager rotate-secret` + `git revert` |
| SQS mensajes estancados | Revisar Lambda consumers, verificar permisos |
| CloudFront error | Verificar origen (S3/ALB), invalidar cache |

---

## 7. Troubleshooting (Solución de Problemas)

### 7.1 Errores Comunes de Terraform

| Error | Causa | Solución |
|-------|-------|----------|
| `Error: Backend initialization` | Backend no configurado | Verificar bucket S3 y credenciales (el lock es nativo del bucket, sin DynamoDB) |
| `Error: Error acquiring the state lock` | Lock activo | `terraform force-unlock <LOCK_ID>` |
| `Error: Provider configuration not present` | Falta provider block | Agregar provider en módulo o raíz |
| `Error: Invalid for_each argument` | Mapa con keys dinámicas | Usar `toset()` o predefinir keys |
| `Error: Cycle dependency` | Dependencia circular | Revisar referencias entre módulos |
| `Error: Unsupported attribute` | Atributo no existe en versión | Actualizar provider o usar atributo correcto |
| `Error: Missing required argument` | Variable requerida sin valor | Definir en `terraform.tfvars` o variable |

### 7.2 Errores Comunes de AWS

| Error | Causa | Solución |
|-------|-------|----------|
| `InvalidBucketName` | Nombre no cumple reglas | Usar naming conventions |
| `AuthorizationError` | Permisos IAM insuficientes | Agregar permisos necesarios |
| `ServiceQuotaExceededException` | Límite de servicio alcanzado | Solicitar aumento de cuota |
| `ResourceNotFoundException` | Recurso no existe | Verificar nombre/ID |
| `DependencyViolation` | Recurso tiene dependencias | Eliminar dependencias primero |
| `InvalidParameterValue` | Parámetro inválido | Revisar documentación del servicio |
| `ThrottlingException` | Demasiadas solicitudes | Implementar backoff exponencial |

### 7.3 Errores de Conectividad

```bash
# Test de conectividad a Aurora
# Desde una EC2 en la VPC:
psql -h <AURORA_ENDPOINT> -U hce_admin -d hce -c "SELECT 1;"

# Si falla:
# 1. Verificar security group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=sg-aurora-ar-prod" \
  --query 'SecurityGroups[*].IpPermissions'

# 2. Verificar subnet
aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=sn-data-ar-prod-us-east-1a" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,DefaultForAz]'

# 3. Verificar ruta
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxx" \
  --query 'RouteTables[*].Routes'

# Test de conectividad a ECS
# Verificar que las tasks están corriendo
aws ecs describe-tasks \
  --cluster ecs-ar-prod \
  --tasks $(aws ecs list-tasks --cluster ecs-ar-prod --query 'taskArns' --output text) \
  --query 'tasks[*].[lastStatus,healthStatus,stoppedReason]' \
  --output table
```

### 7.4 Errores de CI/CD

| Error | Causa | Solución |
|-------|-------|----------|
| `terraform validate failed` | Error de sintaxis | Revisar archivos .tf |
| `terraform test failed` | Test no pasa | Verificar asserts en .tftest.hcl |
| `Apply failed` | Error al crear recurso | Revisar logs, permisos, cuotas |
| `Plan has changes` | Estado desincronizado | Sincronizar con `terraform refresh` |
| `Backend config changed` | Cambio en backend | Re-init con `terraform init -migrate-state` |

### 7.5 Comandos de Diagnóstico

```bash
# Estado actual de Terraform
terraform show

# Listar todos los recursos
terraform state list

# Ver detalles de un recurso
terraform state show aws_ecs_cluster.this

# Importar recurso existente
terraform import aws_vpc.existing vpc-12345678

# Forzar refresh del estado
terraform refresh

# Ver logs de Terraform
export TF_LOG=DEBUG
terraform plan 2>&1 | tee terraform-debug.log

# Verificar configuración
terraform validate

# Verificar formato
terraform fmt -check -recursive
```

---

## 8. Colaboración en Equipo

### 8.1 Flujo de Trabajo Git

El repo usa un flujo **trunk-based**: no hay rama `develop` ni `release/*`. Todas las ramas salen de `main` y vuelven a `main` vía PR.

```
main (única rama de larga vida)
├── feat/xxx    (features)
├── fix/xxx     (bugfixes)
└── docs/xxx    (documentación)
```

### 8.2 Reglas de Ramas

| Rama | Origen | Merge en | Despliegue |
|------|--------|----------|------------|
| `main` | - | - | Preprod y prod **automático** (pipeline tras push) |
| `feat/*` | `main` | `main` (PR) | - |
| `fix/*` | `main` | `main` (PR) | - |
| `docs/*` | `main` | `main` (PR) | - |

### 8.3 Convenciones de Commits

```
<tipo>(<scope>): <descripción>

Tipos:
- feat: nuevo feature
- fix: bug fix
- docs: documentación
- style: formato (no afecta código)
- refactor: refactoring
- test: tests
- chore: mantenimiento

Ejemplos:
feat(network): agregar subnet de datos para AR
fix(compute): corregir health check path
docs(runbook): agregar sección de troubleshooting
```

### 8.4 Code Review Checklist

Al revisar un PR de Terraform:

- [ ] `terraform fmt -check` pasa
- [ ] `terraform validate` pasa
- [ ] `terraform test` pasa
- [ ] No hay credenciales hardcodeadas
- [ ] Tags obligatorios están presentes
- [ ] Naming conventions se cumplen
- [ ] Variables tienen descripciones
- [ ] Outputs están documentados
- [ ] Security groups son restrictivos
- [ ] KMS está habilitado donde corresponde

### 8.5 Herramientas de Comunicación

| Canal | Uso |
|-------|-----|
| **GitHub Issues** | Bugs, features, tareas |
| **GitHub PRs** | Revisiones de código |
| **Slack/Teams** | Comunicación diaria |
| **Documentación** | Decisiones arquitectónicas |

---

## 9. Onboarding de Nuevos Miembros

### 9.1 Prerrequisitos

1. **Acceso a GitHub**: Invitación al repositorio
2. **Acceso a AWS Academy**: Credenciales de la cuenta
3. **Herramientas locales**:
   - Git
   - Terraform >= 1.10.0
   - AWS CLI >= 2.x
   - Docker Desktop (para MiniStack)

### 9.2 Primeros Pasos

```bash
# 1. Clonar repositorio
git clone https://github.com/JosiasTomasnanez/vitalmed-telehealth-platform.git
cd vitalmed-telehealth-platform

# 2. Configurar AWS CLI
aws configure
# Ingresar credenciales de AWS Academy

# 3. Verificar Terraform
terraform version

# 4. Validar código
terraform fmt -recursive
cd terraform/modules/network
terraform init -backend=false
terraform validate

# 5. Ejecutar tests (con MiniStack; ver scripts/*.sh)
./scripts/start-ministack.sh
./scripts/run-tests-ministack.sh
```

### 9.3 Lecturas Recomendadas

1. **Runbook de Despliegue** (`docs/runbook.md`)
2. **Este anexo** (`docs/runbook-operaciones.md`)
3. **README de Terraform**: `terraform/README.md`
4. **Documentación del proyecto**: GitHub Pages
5. **AWS Well-Architected Framework**: [docs](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)

### 9.4 Mentorías

- **Semana 1**: Revisar runbook con mentor
- **Semana 2**: Hacer un PR pequeño (documentación o fix)
- **Semana 3**: Trabajar en un feature con revisión
- **Semana 4**: Participar en despliegue supervisado

---

## 10. Contactos y Escalación

| Rol | Responsabilidad | Contacto |
|-----|-----------------|----------|
| **Tech Lead** | Decisiones arquitectónicas | `tech-lead@vitalmed.com` |
| **DevOps** | Despliegues y operaciones | `devops@vitalmed.com` |
| **Security** | Seguridad y cumplimiento | `security@vitalmed.com` |
| **On-Call** | Incidentes fuera de horario | `oncall@vitalmed.com` |
