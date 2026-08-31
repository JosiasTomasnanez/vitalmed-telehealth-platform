# Runbook de Despliegue — VitalMed Telesalud

**Grupo 9 · Diplomatura DevOps · Pilar: Excelencia Operativa**

---

## 1. Prerrequisitos y Permisos

### 1.1 Cuentas AWS Requeridas

| Cuenta | Propósito | Account ID |
|--------|-----------|------------|
| **Management** | AWS Organizations, facturación central, control de acceso | `var.management_account_id` |
| **shared** | Bucket S3 del state de Terraform y logging centralizado de CloudTrail | `var.shared_account_id` |
| **ar-prod** | VitalMed Argentina (producción) | `var.prod_account_ids.ar` |
| **cl-prod** | VitalMed Chile (producción) | `var.prod_account_ids.cl` |
| **co-prod** | VitalMed Colombia (producción) | `var.prod_account_ids.co` |
| **mx-prod** | VitalMed México (producción) | `var.prod_account_ids.mx` |
| **preprod** | Entorno de preproducción **único y global** (sin distinción de país) | `var.preprod_account_id` |

> **Nota**: son 6 cuentas workload + 1 de management (7 en total con Organizations). No hay cuentas separadas de Security ni de Network, ni preproducción por país: GuardDuty/Security Hub/CloudTrail central quedan como trabajo futuro (ver §8), y la preproducción es una sola cuenta que comparten los cuatro países.

### 1.2 Permisos IAM Necesarios

Para ejecutar los comandos de este runbook, el usuario/rol debe tener:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PassRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "organizations:*",
        "ecs:*",
        "ec2:*",
        "rds:*",
        "lambda:*",
        "sqs:*",
        "kms:*",
        "secretsmanager:*",
        "cloudfront:*",
        "wafv2:*",
        "route53:*",
        "acm:*",
        "cloudwatch:*",
        "logs:*",
        "ecr:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 1.3 Herramientas Requeridas

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| Terraform | >= 1.10.0 | IaC |
| AWS CLI | >= 2.x | Interacción con AWS |
| GitHub CLI | >= 2.x | Gestión de PRs |
| jq | >= 1.6 | Procesamiento de JSON |

---

## 2. Configuración de Variables

### 2.1 Archivos de Variables por País/Entorno

Cada entorno tiene su propio `main.tf` + `variables.tf`:

```bash
terraform/environments/
├── ar/
│   └── prod/                 # VitalMed Argentina (producción)
├── cl/
│   └── prod/                 # VitalMed Chile (producción)
├── co/
│   └── prod/                 # VitalMed Colombia (producción)
├── mx/
│   └── prod/                 # VitalMed México (producción)
└── preprod/                  # preproducción única y global (sin país)
```

### 2.2 Variables de Backend (S3 State)

```hcl
# terraform/environments/ar/prod/main.tf
terraform {
  backend "s3" {
    bucket         = "tp-diplodevops-tfstate-mgmt"
    key            = "environments/ar/prod/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
```

### 2.3 Variables de Entorno

Cada entorno (`environments/<pais>/prod/` y `environments/preprod/`) declara **dos** variables en su `variables.tf`:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `account_id` | ID de la cuenta AWS destino (sale del output `prod_account_ids` o `preprod_account_id` del stack `org/`) | `123456789012` |
| `zona_route53_id` | Hosted zone de Route 53 del dominio raíz (`miapp.com`) donde se crean los registros DNS del entorno | `Z0123456ABCDEF` |

> **Aclaraciones**:
> - `pais` y `entorno` **no son variables**: se pasan como literales a cada módulo en `main.tf` (ej. `pais = "ar"`, `entorno = "prod"`; en preprod `pais = "global"`).
> - El `vpc_cidr` y los rangos de subnets también van inline en `main.tf`, no en `variables.tf`.
> - Los valores por defecto de Aurora (ACU min/max), servicios ECS y colas SQS viven en los módulos (`modules/data`, `modules/compute`, `modules/async`), no en el entorno.

---

## 3. Orden de Despliegue

### 3.1 Despliegue Inicial (Primera Vez)

```bash
# Paso 1: Bootstrap del state backend (bucket S3 con locking nativo use_lockfile)
# Se aplica UNA sola vez, con backend local (aún no existe el bucket remoto).
cd terraform/global/state-backend
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Paso 2: Desplegar AWS Organizations y las cuentas (ya con backend remoto S3)
cd terraform/org
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Paso 3: Desplegar cada país en producción (ejemplo: Argentina)
cd terraform/environments/ar/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Paso 4: Desplegar la preproducción global (una sola vez, sin país)
cd terraform/environments/preprod
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Repetir el Paso 3 para los demás países (cl, co, mx)
```

### 3.2 Despliegue de Actualizaciones

```bash
# 1. Crear rama de feature
git checkout -b feat/nuevo-recurso

# 2. Hacer cambios en terraform/
# ...

# 3. Validar localmente
cd terraform/environments/ar/prod
terraform fmt -check
terraform init -backend=false
terraform validate
terraform test

# 4. Crear PR y esperar aprobación
git add .
git commit -m "feat: agregar recurso X"
git push origin feat/nuevo-recurso

# 5. Después del merge a main, el pipeline CI/CD despliega automáticamente
```

---

## 4. Validaciones Previas al Despliegue

### 4.1 Validación de Código

```bash
# Verificar formato
terraform fmt -check -recursive

# Verificar sintaxis
for dir in terraform/environments/*/*/; do
  if [ -f "$dir/main.tf" ]; then
    cd "$dir"
    terraform init -backend=false
    terraform validate
    cd -
  fi
done

# Ejecutar tests
for module_dir in terraform/modules/*/; do
  if [ -d "${module_dir}tests" ]; then
    cd "$module_dir"
    terraform test
    cd -
  fi
done
```

### 4.2 Validación de Seguridad

```bash
# Verificar que no hay credenciales hardcodeadas
grep -r "password" terraform/ --include="*.tf" | grep -v "variable\|random_password\|secretsmanager"

# Verificar que KMS está habilitado
grep -r "kms_key_id" terraform/ --include="*.tf" | wc -l

# Verificar que S3 buckets tienen cifrado
grep -r "server_side_encryption_configuration" terraform/ --include="*.tf" | wc -l
```

### 4.3 Validación de Arquitectura

```bash
# Verificar que Aurora está en modo Serverless v2
grep -r "engine_mode.*provisioned" terraform/ --include="*.tf"

# Verificar que ECS usa Fargate (sin EC2)
grep -r "requires_compatibilities.*FARGATE" terraform/ --include="*.tf"

# Verificar que las subnets de datos no tienen ruta a Internet
grep -r "aws_route.*data" terraform/ --include="*.tf" | wc -l
```

---

## 5. Validaciones Posteriores al Despliegue

### 5.1 Validación de Recursos

```bash
# Verificar que la VPC existe
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-ar-prod" --query 'Vpcs[0].VpcId' --output text

# Verificar que Aurora está corriendo
aws rds describe-db-clusters --db-cluster-identifier aurora-ar-prod --query 'DBClusters[0].Status' --output text

# Verificar que ECS services están activos
aws ecs list-services --cluster ecs-ar-prod --query 'serviceArns' --output table

# Verificar que CloudFront está desplegado
aws cloudfront list-distributions --query 'DistributionList.Items[0].Status' --output text
```

### 5.2 Validación de Conectividad

```bash
# Test de health check del ALB
curl -s http://<ALB_DNS>/turnos/health

# Test de CloudFront
curl -s -I https://ar.miapp.com

# Test de Aurora (desde una EC2 en la VPC)
psql -h <AURORA_ENDPOINT> -U hce_admin -d hce -c "SELECT 1;"
```

### 5.3 Validación de Seguridad

```bash
# Verificar que CloudTrail está activo
aws cloudtrail get-trail-status --name vitalmed-cloudtrail --query 'IsLogging' --output text

# Verificar que GuardDuty está habilitado
aws guardduty list-detectors --query 'DetectorIds[0]' --output text

# Verificar que S3 buckets no son públicos
aws s3api get-bucket-acl --bucket estudios-medicos-ar-prod --query 'Grants[?Grantee.Uri==`http://acs.amazonaws.com/groups/global/AllUsers`]' --output text
```

---

## 6. Estrategia de Rollback

### 6.1 Rollback Manual

```bash
# Si el despliegue falla, revertir el último cambio
cd terraform/environments/ar/prod

# Ver el último plan aplicado
terraform show

# Revertir al estado anterior (usando S3 versioning)
aws s3api get-object \
  --bucket tp-diplodevops-tfstate-mgmt \
  --key environments/ar/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup

# Aplicar el estado anterior
terraform state push terraform.tfstate.backup
terraform apply
```

### 6.2 Rollback Automático (CI/CD)

El pipeline de GitHub Actions tiene protección de ambientes:

1. **Preproducción**: Se aplica automáticamente después de merge a main
2. **Producción**: Requiere aprobación manual (environment protection rules)

Si el despliegue a preproducción falla:
- El pipeline se detiene
- No se despliega a producción
- Se crea un issue automáticamente

### 6.3 Procedimiento de Emergencia

```bash
# 1. Notificar al equipo
echo "ALERTA: Despliegue fallido en $PAIS $ENVIRON" | \
  curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"ALERTA: Despliegue fallido"}' \
  $SLACK_WEBHOOK_URL

# 2. Congelar despliegues
git tag freeze-deploy-$(date +%Y%m%d)
git push origin freeze-deploy-$(date +%Y%m%d)

# 3. Diagnosticar
cd terraform/environments/$PAIS/$ENVIRON
terraform state list
terraform state show <RECURSO_FALLIDO>

# 4. Corregir y re-desplegar
# ... hacer cambios ...
terraform plan -out=tfplan
terraform apply tfplan

# 5. Des-congelar despliegues
git tag unfreeze-deploy-$(date +%Y%m%d)
git push origin unfreeze-deploy-$(date +%Y%m%d)
```

---

## 7. Pruebas Relacionadas con Excelencia Operativa

### 7.1 Pruebas de Observabilidad

```bash
# Verificar que CloudWatch Logs están recibiendo datos
aws logs describe-log-groups --log-group-name-prefix "/ecs/ar-prod" --query 'logGroups[*].logGroupName' --output table

# Verificar que las alarmas de CloudWatch existen
aws cloudwatch describe-alarms --alarm-name-prefix "ecs-ar-prod" --query 'MetricAlarms[*].AlarmName' --output table

# Verificar que X-Ray está habilitado
aws xray get-service-graph --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --query 'ServiceGraph.Services[*].Name' --output table
```

### 7.2 Pruebas de Seguridad

```bash
# Verificar que no hay buckets S3 públicos
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  xargs -I {} sh -c 'aws s3api get-bucket-acl --bucket {} --query "Grants[?Grantee.Uri==\`http://acs.amazonaws.com/groups/global/AllUsers\`]" --output text | grep -v "^$" && echo "PUBLIC: {}" || echo "PRIVATE: {}"'

# Verificar que Aurora tiene cifrado habilitado
aws rds describe-db-clusters --db-cluster-identifier aurora-ar-prod --query 'DBClusters[0].StorageEncrypted' --output text

# Verificar que Secrets Manager tiene las credenciales
aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `diplodevops/ar-prod/aurora`)].Name' --output text
```

### 7.3 Pruebas de Resiliencia

```bash
# Simular fallo de AZ (chaos engineering)
aws ecs update-service \
  --cluster ecs-ar-prod \
  --service turnos \
  --force-new-deployment

# Verificar que ECS reemplaza las tasks
aws ecs describe-services \
  --cluster ecs-ar-prod \
  --services turnos \
  --query 'services[0].deployments[*].[status,desiredCount,runningCount]' \
  --output table

# Verificar que Aurora fallover funciona
aws rds reboot-db-cluster --db-cluster-identifier aurora-ar-prod
aws rds describe-db-clusters --db-cluster-identifier aurora-ar-prod --query 'DBClusters[0].Status' --output text
```

### 7.4 Pruebas de Auto Scaling

```bash
# Simular carga alta (generar tráfico)
for i in {1..100}; do
  curl -s https://ar.miapp.com/turnos/health &
done

# Verificar que ECS escala
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=ecs-ar-prod Name=ServiceName,Value=turnos \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average

# Verificar que Aurora escala ACUs
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=aurora-ar-prod \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average
```

---

## 8. Limitaciones y Validaciones que Requieren Cuenta Real

### 8.1 Validaciones que Requieren AWS Academy o Cuenta Real

| Validación | Comando | Limitación |
|------------|---------|------------|
| `terraform apply` | `terraform apply` | Requiere credenciales AWS válidas |
| `terraform import` | `terraform import` | Requiere recursos existentes en AWS |
| `aws ec2 describe-*` | CLI de AWS | Requiere permisos IAM |
| `aws rds create-db-cluster` | CLI de AWS | Requiere cuotas de servicio |
| `aws ecs create-service` | CLI de AWS | Requiere permisos IAM |

### 8.2 Validaciones que Funcionan sin Cuenta Real

| Validación | Comando | Requisitos |
|------------|---------|------------|
| Formato de código | `terraform fmt -check` | Ninguno |
| Validación sintáctica | `terraform validate` | Solo `terraform init -backend=false` |
| Tests unitarios | `terraform test` | Solo `terraform init -backend=false` |
| Plan (dry run) | `terraform plan -backend=false` | Solo `terraform init -backend=false` |

### 8.3 Configuración de AWS Academy

Si se usa AWS Academy, las siguientes configuraciones pueden no estar disponibles:

```bash
# Limitaciones conocidas de AWS Academy:
# 1. No se puede crear Organizations
# 2. No se puede usar Control Tower
# 3. Servicios limitados (ej: Chime SDK)
# 4. Cuotas reducidas

# Workaround: Usar una sola cuenta y simular el aislamiento con:
# - VPCs separadas por país
# - Subnets aisladas
# - Security Groups restrictivos
```

---

## 9. Comandos Rápidos de Referencia

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

## 10. Naming Conventions (Convenciones de Nombres)

### 10.1 Estructura de Nombres

```
<pais>-<entorno>-<servicio>-<recurso>
```

| Componente | Valores | Ejemplo |
|------------|---------|---------|
| `pais` | `ar`, `cl`, `co`, `mx` | `ar` |
| `entorno` | `prod`, `preprod` | `prod` |
| `servicio` | `ecs`, `aurora`, `s3`, `sqs`, `lambda`, `alb`, `cf`, `waf` | `ecs` |
| `recurso` | Descriptivo | `turnos`, `pagos` |

### 10.2 Ejemplos por Recurso

| Recurso | Nombre | Ejemplo |
|---------|--------|---------|
| VPC | `vpc-{pais}-{entorno}` | `vpc-ar-prod` |
| Subnet pública | `subnet-{pais}-{entorno}-pub-{az}` | `subnet-ar-prod-pub-a` |
| Subnet privada | `subnet-{pais}-{entorno}-priv-{az}` | `subnet-ar-prod-priv-a` |
| Subnet datos | `subnet-{pais}-{entorno}-data-{az}` | `subnet-ar-prod-data-a` |
| NAT Gateway | `nat-{pais}-{entorno}` | `nat-ar-prod` |
| ALB | `alb-{pais}-{entorno}` | `alb-ar-prod` |
| Security Group ALB | `sg-alb-{pais}-{entorno}` | `sg-alb-ar-prod` |
| Security Group ECS | `sg-ecs-{pais}-{entorno}` | `sg-ecs-ar-prod` |
| ECS Cluster | `ecs-{pais}-{entorno}` | `ecs-ar-prod` |
| ECS Service | `svc-{pais}-{entorno}-{servicio}` | `svc-ar-prod-turnos` |
| Task Definition | `td-{pais}-{entorno}-{servicio}` | `td-ar-prod-turnos` |
| ECR Repository | `ecr-{pais}-{entorno}-{servicio}` | `ecr-ar-prod-turnos` |
| Aurora Cluster | `aurora-{pais}-{entorno}` | `aurora-ar-prod` |
| Aurora Instance | `aurora-{pais}-{entorno}-{n}` | `aurora-ar-prod-1` |
| S3 Bucket | `{tipo}-{pais}-{entorno}` | `estudios-ar-prod` |
| SQS Queue | `cola-{pais}-{entorno}-{servicio}` | `cola-ar-prod-turnos` |
| Lambda Function | `fn-{pais}-{entorno}-{servicio}` | `fn-ar-prod-turnos` |
| CloudFront | `cf-{pais}-{entorno}` | `cf-ar-prod` |
| WAF WebACL | `waf-{pais}-{entorno}` | `waf-ar-prod` |
| KMS Key | `kms-{pais}-{entorno}` | `kms-ar-prod` |
| Log Group | `/ecs/{pais}-{entorno}/{servicio}` | `/ecs/ar-prod/turnos` |

### 10.3 Reglas de Formato

- **Minúsculas**: Todos los nombres en minúsculas
- **Guiones**: Separador principal (`-`)
- **Sin caracteres especiales**: No guiones bajos, puntos ni espacios
- **Longitud máxima**: 63 caracteres (límite de AWS para la mayoría de recursos)
- **Prefijos**: Usar prefijos estándar (`vpc-`, `subnet-`, `sg-`, etc.)

---

## 11. Tagging Strategy (Estrategia de Tags)

### 11.1 Tags Obligatorios

Todos los recursos DEBEN tener estos tags:

| Tag | Descripción | Ejemplo |
|-----|-------------|---------|
| `Pais` | Código del país | `ar`, `cl`, `co`, `mx` |
| `Entorno` | Entorno de despliegue | `prod`, `preprod` |
| `ManagedBy` | Herramienta de gestión | `terraform` |
| `Project` | Nombre del proyecto | `vitalmed` |
| `Team` | Equipo responsable | `devops` |
| `CostCenter` | Centro de costo | `diplomatura-devops` |

### 11.2 Tags Opcionales

| Tag | Descripción | Ejemplo |
|-----|-------------|---------|
| `Service` | Microservicio asociado | `turnos`, `pagos` |
| `Environment` | Alias de Entorno | `production`, `staging` |
| `Owner` | Responsable del recurso | `equipo-devops` |
| `Criticality` | Nivel de criticidad | `high`, `medium`, `low` |
| `Backup` | Política de backup | `daily`, `weekly`, `none` |
| `Expiration` | Fecha de expiración | `2026-12-31` |

### 11.3 Implementación en Terraform

```hcl
# Provider con tags globales
provider "aws" {
  # ...

  default_tags {
    tags = {
      Pais        = var.pais
      Entorno     = var.entorno
      ManagedBy   = "terraform"
      Project     = "vitalmed"
      Team        = "devops"
      CostCenter  = "diplomatura-devops"
    }
  }
}

# Tags adicionales por recurso
resource "aws_ecs_cluster" "this" {
  name = "ecs-${local.nombre}"

  tags = {
    Service    = "general"
    Criticality = "high"
  }
}
```

### 11.4 Validación de Tags

```bash
# Verificar que todos los recursos tienen tags obligatorios
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=terraform" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Pais`].Value|[0],Tags[?Key==`Entorno`].Value|[0]]' \
  --output table

# Recursos sin tag Pais
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=terraform" \
  --query 'Reservations[*].Instances[?!Tags[?Key==`Pais`]].InstanceId' \
  --output text
```

---

## 12. Monitoreo y Alertas

### 12.1 Métricas Clave a Monitorear

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

### 12.2 Alarmas de CloudWatch

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

### 12.3 Dashboard de CloudWatch

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

### 12.4 SNS Topics para Alertas

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

## 13. Backup y Recovery

### 13.1 Backup de Estado de Terraform

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

### 13.2 Backup de Aurora

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

### 13.3 Backup de S3

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

### 13.4 Procedimiento de Recovery

```bash
# 1. Detener despliegues
git tag freeze-deploy-$(date +%Y%m%d)
git push origin freeze-deploy-$(date +%Y%m%d)

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
  --bucket estudios-ar-prod \
  --prefix <PATH> \
  --query 'Versions[0].VersionId' \
  --output text
# Luego usar version-id para restaurar

# 6. Verificar restauración
# ... tests de conectividad ...

# 7. Des-congelar despliegues
git tag unfreeze-deploy-$(date +%Y%m%d)
git push origin unfreeze-deploy-$(date +%Y%m%d)
```

---

## 14. Seguridad - Incident Response

### 14.1 Tipos de Incidentes

| Severidad | Descripción | Ejemplo |
|-----------|-------------|---------|
| **P1 - Crítico** | Riesgo de datos o servicio caído | Breach de seguridad, Aurora caído |
| **P2 - Alto** | Degradación significativa | ALB con errores, latencia alta |
| **P3 - Medio** | Issue menor | Log group lleno, métrica anómala |
| **P4 - Bajo** | Mejora o documentación | Optimización de costos |

### 14.2 Procedimiento de Respuesta

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
# CloudTrail - Últimas acciones
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --query 'Events[*].[EventTime,Username,EventName,SourceIPAddress]' \
  --output table

# GuardDuty - Hallazgos
aws guardduty list-findings \
  --finding-criteria '{"Criterion": {"severity": {"Gte": 7}}}' \
  --query 'FindingIds' \
  --output text

# VPC Flow Logs - Tráfico sospechoso
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
  --secret-id vitalmed/ar-prod/aurora/credentials

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

### 14.3 Playbooks Rápidos

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

## 15. Troubleshooting (Solución de Problemas)

### 15.1 Errores Comunes de Terraform

| Error | Causa | Solución |
|-------|-------|----------|
| `Error: Backend initialization` | Backend no configurado | Verificar bucket S3 y credenciales (el lock es nativo del bucket, sin DynamoDB) |
| `Error: Error acquiring the state lock` | Lock activo | `terraform force-unlock <LOCK_ID>` |
| `Error: Provider configuration not present` | Falta provider block | Agregar provider en módulo o raíz |
| `Error: Invalid for_each argument` | Mapa con keys dinámicas | Usar `toset()` o predefinir keys |
| `Error: Cycle dependency` | Dependencia circular | Revisar referencias entre módulos |
| `Error: Unsupported attribute` | Atributo no existe en versión | Actualizar provider o usar atributo correcto |
| `Error: Missing required argument` | Variable requerida sin valor | Definir en `terraform.tfvars` o variable |

### 15.2 Errores Comunes de AWS

| Error | Causa | Solución |
|-------|-------|----------|
| `InvalidBucketName` | Nombre no cumple reglas | Usar naming conventions |
| `AuthorizationError` | Permisos IAM insuficientes | Agregar permisos necesarios |
| `ServiceQuotaExceededException` | Límite de servicio alcanzado | Solicitar aumento de cuota |
| `ResourceNotFoundException` | Recurso no existe | Verificar nombre/ID |
| `DependencyViolation` | Recurso tiene dependencias | Eliminar dependencias primero |
| `InvalidParameterValue` | Parámetro inválido | Revisar documentación del servicio |
| `ThrottlingException` | Demasiadas solicitudes | Implementar backoff exponencial |

### 15.3 Errores de Conectividad

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
  --filters "Name=subnet-id,Values=subnet-data-ar-prod-1" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,DefaultForAz]'

# 3. Verificar ruta
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-data-ar-prod-1" \
  --query 'RouteTables[*].Routes'

# Test de conectividad a ECS
# Verificar que las tasks están corriendo
aws ecs describe-tasks \
  --cluster ecs-ar-prod \
  --tasks $(aws ecs list-tasks --cluster ecs-ar-prod --query 'taskArns' --output text) \
  --query 'tasks[*].[lastStatus,healthStatus,stoppedReason]' \
  --output table
```

### 15.4 Errores de CI/CD

| Error | Causa | Solución |
|-------|-------|----------|
| `terraform validate failed` | Error de sintaxis | Revisar archivos .tf |
| `terraform test failed` | Test no pasa | Verificar asserts en .tftest.hcl |
| `Apply failed` | Error al crear recurso | Revisar logs, permisos, cuotas |
| `Plan has changes` | Estado desincronizado | Sincronizar con `terraform refresh` |
| `Backend config changed` | Cambio en backend | Re-init con `terraform init -migrate-state` |

### 15.5 Comandos de Diagnóstico

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

## 16. Colaboración en Equipo

### 16.1 Flujo de Trabajo Git

```
main (producción)
├── develop (integración)
│   ├── feat/xxx (features)
│   ├── fix/xxx (bugfixes)
│   └── docs/xxx (documentación)
└── release/x.x.x (releases)
```

### 16.2 Reglas de Ramas

| Rama | Origen | Merge en | Despliegue |
|------|--------|----------|------------|
| `main` | - | - | Producción (manual) |
| `develop` | `main` | `main` | Preproducción (auto) |
| `feat/*` | `develop` | `develop` | - |
| `fix/*` | `develop` | `develop` | - |

### 16.3 Convenciones de Commits

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

### 16.4 Code Review Checklist

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

### 16.5 Herramientas de Comunicación

| Canal | Uso |
|-------|-----|
| **GitHub Issues** | Bugs, features, tareas |
| **GitHub PRs** | Revisiones de código |
| **Slack/Teams** | Comunicación diaria |
| **Documentación** | Decisiones arquitectónicas |

---

## 17. Onboarding de Nuevos Miembros

### 17.1 Prerrequisitos

1. **Acceso a GitHub**: Invitación al repositorio
2. **Acceso a AWS Academy**: Credenciales de la cuenta
3. **Herramientas locales**:
   - Git
   - Terraform >= 1.10.0
   - AWS CLI >= 2.x
   - Docker Desktop (para MiniStack)

### 17.2 Primeros Pasos

```bash
# 1. Clonar repositorio
git clone https://github.com/grupo9-vitalmed/vitalmed-telehealth-platform.git
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

# 5. Ejecutar tests
.\scripts\start-ministack.ps1
.\scripts\run-tests-ministack.ps1
```

### 17.3 Lecturas Recomendadas

1. **Este runbook** (completo)
2. **README de Terraform**: `terraform/README.md`
3. **Documentación del proyecto**: GitHub Pages
4. **AWS Well-Architected Framework**: [docs](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)

### 17.4 Mentorías

- **Semana 1**: Revisar runbook con mentor
- **Semana 2**: Hacer un PR pequeño (documentación o fix)
- **Semana 3**: Trabajar en un feature con revisión
- **Semana 4**: Participar en despliegue supervisado

---

## 18. Contactos y Escalación

| Rol | Responsabilidad | Contacto |
|-----|-----------------|----------|
| **Tech Lead** | Decisiones arquitectónicas | `tech-lead@vitalmed.com` |
| **DevOps** | Despliegues y operaciones | `devops@vitalmed.com` |
| **Security** | Seguridad y cumplimiento | `security@vitalmed.com` |
| **On-Call** | Incidentes fuera de horario | `oncall@vitalmed.com` |

---

**Última actualización**: 2026-08-26  
**Versión**: 2.0  
**Autor**: Grupo 9 — Diplomatura DevOps
