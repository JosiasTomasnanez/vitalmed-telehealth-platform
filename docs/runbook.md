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
# Verificar que S3 buckets no son públicos
aws s3api get-bucket-acl --bucket diplodevops-ar-prod-estudios-medicos --query 'Grants[?Grantee.Uri==`http://acs.amazonaws.com/groups/global/AllUsers`]' --output text
```

---

## 6. Estrategia de Rollback

### 6.1 Rollback Manual

```bash
# Si un despliegue introdujo un problema, volver al último estado bueno.
cd terraform/environments/ar/prod

# 1. Revertir el CÓDIGO (la fuente de verdad) al commit anterior
git revert <COMMIT_PROBLEMATICO>

# 2. Re-aplicar el código revertido
terraform plan -out=tfplan
terraform apply tfplan

# 3. Si además el state quedó corrupto o incompleto, restaurar la versión
#    anterior del state usando el versioning del bucket S3 (habilitado en
#    global/state-backend):
aws s3api get-object \
  --bucket tp-diplodevops-tfstate-mgmt \
  --key environments/ar/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup

terraform state push terraform.tfstate.backup
```

> Restaurar solo el state **no** revierte la infraestructura: hay que revertir el código (paso 1) y re-aplicar (paso 2) para que Terraform reconstruya el estado deseado.

### 6.2 Rollback Automático (CI/CD)

El pipeline (`.github/workflows/terraform-ci-cd.yml`) encadena dos etapas tras un push a `main`:

1. **Preproducción** (`deploy-preprod`): `terraform apply` automático a `environments/preprod`.
2. **Producción** (`deploy-prod`): `terraform apply` automático a los 4 países, y **solo se ejecuta si preprod terminó OK** (`needs: [deploy-preprod]`).

Si preproducción falla:
- El pipeline se detiene.
- Producción **no** se despliega (dependencia entre jobs).

> **Rollback en CI/CD**: revertir el commit que rompió (`git revert` + PR a `main`) y dejar que el pipeline re-aplique el estado anterior. Los entornos de GitHub (`preprod`, `prod-{ar,cl,co,mx}`) permiten configurar protección (required reviewers / aprobación manual), pero eso es configuración del repositorio, no del código.

### 6.3 Procedimiento de Emergencia

```bash
# 1. Notificar al equipo
echo "ALERTA: Despliegue fallido en $PAIS $ENVIRON" | \
  curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"ALERTA: Despliegue fallido"}' \
  $SLACK_WEBHOOK_URL

# 2. Congelar despliegues: desactivar el workflow o proteger main
#    Opción A (UI): GitHub > Actions > "Terraform CI/CD" > Disable workflow
#    Opción B (CLI): agregar regla de protección en la rama main
#    (un `git tag freeze-*` NO detiene el pipeline, solo sirve de marcador)
#    (el workflow se dispara por push a main con paths: terraform/**)

# 3. Diagnosticar
cd terraform/environments/$PAIS/$ENVIRON
terraform state list
terraform state show <RECURSO_FALLIDO>

# 4. Corregir y re-desplegar
# ... hacer cambios ...
terraform plan -out=tfplan
terraform apply tfplan

# 5. Des-congelar despliegues: re-habilitar el workflow / quitar la protección
```

---

## 7. Pruebas Relacionadas con Excelencia Operativa

### 7.1 Pruebas de Observabilidad

```bash
# Verificar que CloudWatch Logs están recibiendo datos
aws logs describe-log-groups --log-group-name-prefix "/ecs/ar-prod" --query 'logGroups[*].logGroupName' --output table

# Verificar que las alarmas de CloudWatch existen
aws cloudwatch describe-alarms --alarm-name-prefix "ecs-ar-prod" --query 'MetricAlarms[*].AlarmName' --output table
```

### 7.2 Pruebas de Seguridad

```bash
# Verificar que no hay buckets S3 públicos
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  xargs -I {} sh -c 'aws s3api get-bucket-acl --bucket {} --query "Grants[?Grantee.Uri==\`http://acs.amazonaws.com/groups/global/AllUsers\`]" --output text | grep -v "^$" && echo "PUBLIC: {}" || echo "PRIVATE: {}"'

# Verificar que Aurora tiene cifrado habilitado
aws rds describe-db-clusters --db-cluster-identifier aurora-ar-prod --query 'DBClusters[0].StorageEncrypted' --output text

# Verificar que Secrets Manager tiene las credenciales
aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `diplodevops/ar-prod/aurora-credentials`)].Name' --output text
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
| Plan (dry run) | `terraform plan` | `terraform init -backend=false` + credenciales AWS (reales o mock) |

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

### 8.4 Servicios "Solo Diseño" (requieren cuenta real o trabajo futuro)

Los siguientes servicios forman parte de la arquitectura pero **no están provisionados por el Terraform actual** (ver `terraform/README.md`), por lo que sus validaciones no aplican en un despliegue estándar y deben postergarse a cuando se despliegue en una cuenta real:

| Servicio | Estado | Validación diferida |
|----------|--------|---------------------|
| **CloudTrail** (trail organizacional) | Solo diseño | `aws cloudtrail get-trail-status` (cuando se active el trail en la cuenta shared) |
| **GuardDuty** | Solo diseño | `aws guardduty list-detectors` (requiere habilitar el detector por cuenta) |
| **X-Ray** | Solo diseño | `aws xray get-service-graph` (requiere instrumentar el SDK en cada microservicio) |
| **Security Hub** | Solo diseño | postura agregada tras habilitar GuardDuty/Config en cada cuenta |

> Las validaciones de CloudWatch **sí aplican**: los log groups de ECS y el Container Insights están codeados en `modules/compute`.

---

## 9. Referencia Rápida

Comandos de uso frecuente (el material operativo completo está en el [Anexo de Operaciones](./runbook-operaciones.md)):

```bash
# Formatear y validar todo el repo
terraform fmt -check -recursive
./scripts/validate-terraform.sh

# Ejecutar los tests con MiniStack
./scripts/start-ministack.sh
./scripts/run-tests-ministack.sh

# Estado de un entorno
cd terraform/environments/ar/prod
terraform state list
```

### 9.1 Dónde está el resto

| Tema | Ubicación |
|------|-----------|
| Comandos rápidos (completo) | `runbook-operaciones.md` §1 |
| Naming conventions | `runbook-operaciones.md` §2 |
| Tagging strategy | `runbook-operaciones.md` §3 |
| Monitoreo y alertas | `runbook-operaciones.md` §4 |
| Backup y recovery | `runbook-operaciones.md` §5 |
| Incident response | `runbook-operaciones.md` §6 |
| Troubleshooting | `runbook-operaciones.md` §7 |
| Colaboración y flujo Git | `runbook-operaciones.md` §8 |
| Onboarding | `runbook-operaciones.md` §9 |
| Contactos y escalación | `runbook-operaciones.md` §10 |

---

**Última actualización**: 2026-08-31
**Versión**: 2.1
**Autor**: Grupo 9 — Diplomatura DevOps
