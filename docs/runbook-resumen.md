# Runbook de Despliegue — Resumen Ejecutivo

**Grupo 9 · Diplomatura DevOps · Pilar: Excelencia Operativa**

## 1. Prerrequisitos y permisos

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

> **Nota**: son 6 cuentas workload + 1 de management (7 en total con Organizations). No hay cuentas separadas de Security ni de Network, ni preproducción por país: GuardDuty/Security Hub/CloudTrail central quedan como trabajo futuro, y la preproducción es una sola cuenta que comparten los cuatro países.

### 1.2 Permisos IAM Necesarios

Rol de despliegue con acceso a `organizations`, `s3`, `ecs`, `rds`, `lambda`, `sqs`, `kms`, `secretsmanager`, `cloudfront`, `wafv2`, `route53`, `acm`, `cloudwatch`, `logs`, `ecr`.

### 1.3 Herramientas Requeridas

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| Terraform | >= 1.10.0 | IaC |
| AWS CLI | >= 2.x | Interacción con AWS |
| GitHub CLI | >= 2.x | Gestión de PRs |
| jq | >= 1.6 | Procesamiento de JSON |

## 2. Configuración de variables

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

### 2.2 Variables de Entorno

Cada entorno (`environments/<pais>/prod/` y `environments/preprod/`) declara **dos** variables en su `variables.tf`:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `account_id` | ID de la cuenta AWS destino (sale del output `prod_account_ids` o `preprod_account_id` del stack `org/`) | `123456789012` |
| `zona_route53_id` | Hosted zone de Route 53 del dominio raíz (`miapp.com`) donde se crean los registros DNS del entorno | `Z0123456ABCDEF` |

> **Aclaraciones**:
> - `pais` y `entorno` **no son variables**: se pasan como literales a cada módulo en `main.tf` (ej. `pais = "ar"`, `entorno = "prod"`; en preprod `pais = "global"`).
> - El `vpc_cidr` y los rangos de subnets también van inline en `main.tf`, no en `variables.tf`.
> - Los valores por defecto de Aurora (ACU min/max), servicios ECS y colas SQS viven en los módulos (`modules/data`, `modules/compute`, `modules/async`), no en el entorno.

## 3. Orden de despliegue

### 3.1 Despliegue Inicial (Primera Vez)

1. `terraform/global/state-backend` — bootstrap del bucket, backend local (una sola vez).
2. `terraform/org` — Organizations + account factory (4 prod, preprod, shared).
3. `terraform/environments/<pais>/prod` — un país por vez (`ar`, `cl`, `co`, `mx`).
4. `terraform/environments/preprod` — preproducción global, una sola vez.

### 3.2 Despliegue de Actualizaciones

Flujo de trabajo colaborativo para cambios o nuevas funcionalidades:
1. **Rama de feature**: Se crea una rama a partir de `main` y se realizan las modificaciones en `terraform/`.
2. **Pull Request (PR)**: Se abre un PR hacia `main` para revisión de pares (peer review).
3. **Despliegue por CI/CD**: Una vez aprobado el PR y realizado el merge a `main`, el pipeline de CI/CD despliega los cambios automáticamente.

## 4. Validaciones

### 4.1 Validaciones Previas al Despliegue

1. **Verificación de formato**:
```bash
terraform fmt -check -recursive
```

2. **Verificación de sintaxis**:
```bash
for dir in terraform/environments/*/*/; do
  if [ -f "$dir/main.tf" ]; then
    cd "$dir"
    terraform init -backend=false
    terraform validate
    cd -
  fi
done
```

3. **Testing**:
```bash
for module_dir in terraform/modules/*/; do
  if [ -d "${module_dir}tests" ]; then
    cd "$module_dir"
    terraform test
    cd -
  fi
done
```

4. **Validación de Seguridad**:
   - Verificación de ausencia de credenciales hardcodeadas en archivos `.tf`.
   - Verificación de claves KMS asignadas y habilitadas por país.
   - Verificación de cifrado habilitado en todos los buckets S3.

5. **Validación de Arquitectura**:
   - Verificación de Aurora en modo Serverless v2.
   - Verificación de tareas ECS sobre Fargate (sin instancias EC2).
   - Verificación de subnets de datos completamente aisladas sin ruta a Internet.

### 4.2 Validaciones Posteriores al Despliegue

1. **Validación de Recursos**: Verificación de existencia y estado activo de la VPC, clúster Aurora, servicios ECS y distribuciones CloudFront.
2. **Validación de Conectividad**: Health check del ALB (`/turnos/health`), respuesta HTTPS en CloudFront y consulta de prueba a la base de datos Aurora.
3. **Validación de Seguridad**: Verificación de ACLs en buckets S3 para garantizar que no tengan acceso público.

## 5. Estrategia de rollback

### 5.1 Rollback Manual

Si un despliegue introdujo un problema en un entorno (ejemplo `environments/ar/prod`):

1. **Revertir el código** (la fuente de verdad) al commit anterior:
```bash
cd terraform/environments/ar/prod
git revert <COMMIT_PROBLEMATICO>
```

2. **Re-aplicar el código revertido**:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

3. **Restaurar la versión anterior del state** (si quedó corrupto o incompleto) usando el versioning del bucket S3:
```bash
aws s3api get-object \
  --bucket tp-diplodevops-tfstate-mgmt \
  --key environments/ar/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup

terraform state push terraform.tfstate.backup
```

> Restaurar solo el state **no** revierte la infraestructura: hay que revertir el código (paso 1) y re-aplicar (paso 2) para que Terraform reconstruya el estado deseado.

### 5.2 Rollback Automático (CI/CD)

El pipeline (`.github/workflows/terraform-ci-cd.yml`) encadena dos etapas tras un push a `main`:

1. **Preproducción** (`deploy-preprod`): `terraform apply` automático a `environments/preprod`.
2. **Producción** (`deploy-prod`): `terraform apply` automático a los 4 países, y **solo se ejecuta si preprod terminó OK** (`needs: [deploy-preprod]`).

Si preproducción falla:
- El pipeline se detiene.
- Producción **no** se despliega (dependencia entre jobs).

> **Rollback en CI/CD**: revertir el commit que rompió (`git revert` + PR a `main`) y dejar que el pipeline re-aplique el estado anterior. Los entornos de GitHub (`preprod`, `prod-{ar,cl,co,mx}`) permiten configurar protección (required reviewers / aprobación manual), pero eso es configuración del repositorio, no del código.

## 6. Pruebas de Excelencia Operativa

### 6.1 Pruebas de Observabilidad

- Verificación de la recepción de logs de microservicios en los grupos de logs de CloudWatch.
- Verificación de la existencia y estado activo de las alarmas métricas de CloudWatch.

### 6.2 Pruebas de Seguridad

- Verificación de políticas de almacenamiento privado en Amazon S3 (ausencia de buckets públicos).
- Verificación del cifrado en reposo habilitado con AWS KMS en el clúster de Amazon Aurora.
- Verificación de la gestión y disponibilidad de credenciales en AWS Secrets Manager.

### 6.3 Pruebas de Resiliencia

- Simulación de fallos de zona de disponibilidad forzando nuevos despliegues de tareas en ECS.
- Verificación del reemplazo automático de tareas por parte del orquestador de ECS.
- Verificación del mecanismo de *failover* automático del clúster de base de datos Aurora.

### 6.4 Pruebas de Auto Scaling

- Simulación de carga alta de tráfico web en la plataforma.
- Verificación del escalado horizontal automático de tareas en ECS Fargate según utilización de CPU.
- Verificación del escalado vertical automático de ACUs en Aurora Serverless v2.

## 7. Limitaciones que requieren cuenta real

### 7.1 Validaciones que Requieren AWS Academy o Cuenta Real

| Validación | Comando | Limitación |
|------------|---------|------------|
| `terraform apply` | `terraform apply` | Requiere credenciales AWS válidas |
| `terraform import` | `terraform import` | Requiere recursos existentes en AWS |
| `aws ec2 describe-*` | CLI de AWS | Requiere permisos IAM |
| `aws rds create-db-cluster` | CLI de AWS | Requiere cuotas de servicio |
| `aws ecs create-service` | CLI de AWS | Requiere permisos IAM |

### 7.2 Validaciones que Funcionan sin Cuenta Real

| Validación | Comando | Requisitos |
|------------|---------|------------|
| Formato de código | `terraform fmt -check` | Ninguno |
| Validación sintáctica | `terraform validate` | Solo `terraform init -backend=false` |
| Tests unitarios | `terraform test` | Solo `terraform init -backend=false` |
| Plan (dry run) | `terraform plan` | `terraform init -backend=false` + credenciales AWS (reales o mock) |

### 7.3 Servicios "Solo Diseño" (requieren cuenta real o trabajo futuro)

Los siguientes servicios forman parte de la arquitectura pero **no están provisionados por el Terraform actual** (ver `terraform/README.md`), por lo que sus validaciones no aplican en un despliegue estándar y deben postergarse a cuando se despliegue en una cuenta real:

| Servicio | Estado | Validación diferida |
|----------|--------|---------------------|
| **CloudTrail** (trail organizacional) | Solo diseño | `aws cloudtrail get-trail-status` (cuando se active el trail en la cuenta shared) |
| **GuardDuty** | Solo diseño | `aws guardduty list-detectors` (requiere habilitar el detector por cuenta) |
| **X-Ray** | Solo diseño | `aws xray get-service-graph` (requiere instrumentar el SDK en cada microservicio) |
| **Security Hub** | Solo diseño | postura agregada tras habilitar GuardDuty/Config en cada cuenta |

> Las validaciones de CloudWatch **sí aplican**: los log groups de ECS y el Container Insights están codeados en `modules/compute`.

---

**Autor**: Grupo 9 — Diplomatura DevOps
