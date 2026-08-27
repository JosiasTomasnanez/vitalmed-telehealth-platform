# TP DiploDevOps — Infraestructura AWS multi-país (Terraform)

## Estado del código

| Capa | Estado | Ubicación |
| :--- | :--- | :--- |
| Bootstrap del backend de Terraform | ✅ Codeado | `global/state-backend/` |
| Organizations / Account Factory | ✅ Codeado | `org/` |
| Network (VPC por país+entorno) | ✅ Codeado | `modules/network/` |
| Backend & APIs (ALB, ECS Fargate, ECR) | ✅ Codeado | `modules/compute/` |
| Persistencia (Aurora Serverless v2, S3+KMS, Secrets Manager) | ✅ Codeado | `modules/data/` |
| Procesos asíncronos (SQS, Lambda) | ✅ Codeado | `modules/async/` |
| Certificados (ACM) | ✅ Codeado | `modules/edge-cert/` |
| Borde (CloudFront, WAF, Route 53) | ✅ Codeado | `modules/edge/` |
| Bucket de frontend estático | ✅ Codeado | `modules/frontend-bucket/` |
| Los 8 entornos (país × prod/preprod) | ✅ Codeado | `environments/<pais>/<entorno>/` |
| Tests de Terraform | ✅ Codeado (33 tests) | `modules/*/tests/` |
| CI/CD Pipeline | ✅ Codeado | `.github/workflows/terraform-ci-cd.yml` |
| Runbook de despliegue | ✅ Codeado | `docs/runbook.md` |
| Validación local con MiniStack | ✅ Configurado | `tests/`, `scripts/` |
| Control Tower | 📄 Solo diseño (ver abajo) | — |
| SCPs | 📄 Solo diseño (ver abajo) | — |
| IAM Identity Center | 📄 Solo diseño (ver abajo) | — |
| Amazon Chime SDK | 📄 Solo diseño + permiso IAM | — |
| Security Hub | 📄 Solo diseño (ver abajo) | — |
| CloudWatch / CloudTrail / X-Ray | 📄 Solo diseño (ver abajo) | — |

## Diseño de cuentas

- **1 cuenta management** (Organizations, `org/`): crea y gobierna las 8 cuentas workload + 1 cuenta shared.
- **8 cuentas workload**: {AR, CL, CO, MX} × {prod, preprod}, cada una con su propia VPC, ALB, ECS, Aurora, S3, colas y CDN — aislamiento total, no solo lógico.
- **1 cuenta shared**: aloja el bucket S3 del state de Terraform (`global/state-backend/`) y, más adelante, logging centralizado de CloudTrail.

## Orden de aplicación (importante)

1. `global/state-backend/` — con backend local. Se aplica una única vez, en la cuenta shared. Crea solo el bucket S3, con locking nativo (`use_lockfile`, disponible desde Terraform 1.10).
2. `org/` — crea las 8 cuentas + la cuenta shared. A partir de acá ya se puede usar el backend remoto S3.
3. Creación de environments por cada `environments/<pais>/<entorno>/` — pasando el `account_id` correspondiente (output de `org/`) y el `zona_route53_id` del dominio raíz.

Dentro de cada `environments/<pais>/<entorno>/`, el orden interno de dependencias entre módulos ya está resuelto por Terraform vía referencias (`module.x.output`) — no hace falta aplicarlos por separado. El único punto no trivial es que `edge-cert` (ACM) se separó de `edge` (CloudFront/WAF/Route53) para evitar una dependencia circular: `compute` necesita el certificado antes de que exista el ALB, y `edge` necesita el DNS del ALB para armar el origin de CloudFront.

## Tests de Terraform

### Resumen de tests

| Módulo | Tests | Estado |
|--------|-------|--------|
| network | 3 | ✅ Todos pasaron |
| compute | 8 | ✅ Todos pasaron |
| data | 9 | ✅ Todos pasaron |
| edge | 7 | ✅ Todos pasaron |
| async | 6 | ✅ Todos pasaron |
| **Total** | **33** | ✅ |

### Cómo ejecutar los tests

Los tests se ejecutan localmente utilizando **MiniStack** como emulador de AWS.

```powershell
# 1. Iniciar MiniStack
.\scripts\start-ministack.ps1

# 2. Ejecutar todos los tests
.\scripts\run-tests-ministack.ps1

# 3. Ejecutar tests de un módulo específico
.\scripts\run-tests-ministack.ps1 -Module network
```

### Qué validan los tests

- **network**: VPC, subnets (públicas, privadas, datos), NAT Gateway, route tables, tags
- **compute**: ECS Cluster, ECR repos, task definitions, Fargate, ALB, auto scaling, log groups
- **data**: Aurora PostgreSQL, encryption KMS, logging, Secrets Manager, S3 buckets
- **edge**: CloudFront distribution, WAF Web ACL, Route53 records, TLS 1.2
- **async**: SQS queues, Lambda functions, event source mappings, encryption

### Correcciones aplicadas durante tests

| Archivo | Corrección |
|---------|------------|
| `modules/compute/alb.tf` | Security group names: removido prefijo `sg-` inválido |
| `modules/data/aurora.tf` | Security group name: removido prefijo `sg-` inválido |
| `modules/edge/route53.tf` | Agregado data source para buscar hosted zone por nombre |
| `modules/*/tests/*.tftest.hcl` | ARNs: corregido account ID a 12 dígitos |
| `modules/*/tests/*.tftest.hcl` | Assertions: corregido indexing de sets con `for` expressions |

## CI/CD Pipeline

El pipeline de GitHub Actions ejecuta automáticamente:

1. **Validate**: `terraform fmt -check`, `terraform validate`
2. **Test**: Ejecución de tests con MiniStack
3. **Deploy Preprod**: Despliegue automático a preproducción (requiere aprobación)
4. **Deploy Prod**: Despliegue manual a producción

Ubicación: `.github/workflows/terraform-ci-cd.yml`

## Validación local con MiniStack

### Requisitos

- Docker Desktop
- Terraform >= 1.10.0
- Python 3.x (para tflocal)

### Inicio rápido

```powershell
# Iniciar MiniStack
docker run -d --name ministack -p 4566:4566 ministackorg/ministack

# Verificar salud
curl http://localhost:4566/_ministack/health

# Ejecutar validación completa
.\scripts\validate-terraform.ps1
```

### Servicios emulados

MiniStack emula los servicios de AWS utilizados en el proyecto:
- EC2, VPC, Subnets, Security Groups
- ECS, ECR, ALB, Auto Scaling
- RDS (Aurora), S3, KMS, Secrets Manager
- SQS, Lambda, IAM
- CloudFront, WAF, Route53, ACM
- CloudWatch Logs

Documentación completa: `terraform/tests/README.md`

## Por qué algunos servicios quedan "solo diseño"

- **Control Tower**: se aprovisiona mediante un flujo guiado propio (landing zone) y la mayoría de sus recursos no tienen recurso de Terraform nativo — se administra desde la consola o con el SDK/CLI de Control Tower, no con `terraform apply`. El módulo `org/` reemplaza su función central (Organizations + OUs + account factory) con recursos que sí son 100% Terraform.
- **SCPs**: una vez con la estructura de OUs de `org/`, se agregarían como `aws_organizations_policy` adjuntas a cada OU de país (ej: "deny si la región no es us-east-1", "deny a servicios fuera del stack aprobado"). No se codean todavía porque conviene definir primero qué acciones se quieren permitir/denegar por país según la normativa local (ej. requisitos de residencia de datos de salud en cada país).
- **IAM Identity Center**: requiere estar habilitado a nivel Organization (ya lo dejamos habilitado como servicio en `org/organization.tf`) y luego configurar un Identity Source (AD, o el store nativo) — ese paso inicial no es manejable por Terraform, pero los Permission Sets posteriores sí (`aws_ssoadmin_permission_set`).
- **Amazon Chime SDK**: es consumido vía SDK desde el propio backend (se crean "meetings" dinámicamente en runtime, no son recursos declarativos de infraestructura). El único artefacto de Terraform relacionado es el permiso IAM (`chime:CreateMeeting`, etc.) que ya está adjunto al `task_role` de ECS en cada environment.
- **Security Hub**: se puede activar con `aws_securityhub_account`, pero requiere antes tener GuardDuty/Config habilitados en cada cuenta para que aporte valor real — queda documentado como el siguiente paso natural después de tener las 9 cuentas desplegadas.
- **CloudWatch / X-Ray**: CloudWatch ya está parcialmente codeado (Container Insights en ECS, log groups por microservicio, logs de Postgres de Aurora). X-Ray requeriría instrumentar el código de cada microservicio (SDK de X-Ray en la app), por eso queda fuera del alcance de infraestructura pura.
- **CloudTrail**: se activaría a nivel Organization (trail organizacional único que registra las 9 cuentas) apuntando al bucket de logs de la cuenta shared — es el paso natural siguiente a tener `org/` aplicado.

## Estructura del repo

```
terraform/
├── global/state-backend/         # bootstrap: bucket S3 con locking nativo (use_lockfile)
├── org/                          # cuenta management: Organizations + account factory
├── modules/                      # cada uno se referencia por Git+tag desde environments/, no por path local
│   ├── network/                  # VPC, subnets, NAT, route tables
│   │   └── tests/                # tests de VPC, subnets, tags
│   ├── compute/                  # ALB, ECS Fargate, ECR
│   │   └── tests/                # tests de ECS, ECR, ALB, auto scaling
│   ├── data/                     # Aurora Serverless v2, S3+KMS, Secrets Manager
│   │   └── tests/                # tests de Aurora, S3, KMS
│   ├── async/                    # SQS, Lambda
│   │   └── tests/                # tests de SQS, Lambda, event source mappings
│   ├── edge-cert/                # ACM (separado para evitar ciclo compute<->edge)
│   ├── edge/                     # CloudFront, WAF, Route 53
│   │   └── tests/                # tests de CloudFront, WAF, Route53
│   └── frontend-bucket/          # bucket S3 privado para el build estático, servido por CloudFront
├── environments/
│   ├── ar/{prod,preprod}/
│   ├── cl/{prod,preprod}/
│   ├── co/{prod,preprod}/
│   └── mx/{prod,preprod}/        # cada uno instancia los 7 módulos vía source = "git::...?ref=v1.0"
├── tests/                        # configuración de testing
│   ├── README.md                 # documentación de tests
│   └── ministack-provider.tf     # provider para MiniStack
└── scripts/
    ├── start-ministack.ps1       # inicia MiniStack
    ├── run-tests-ministack.ps1   # ejecuta tests
    └── validate-terraform.ps1    # validación completa
```

## Comandos útiles

```bash
# Formateo
terraform fmt -recursive

# Validación de un módulo
cd terraform/modules/network
terraform init -backend=false
terraform validate

# Tests con MiniStack
.\scripts\start-ministack.ps1
.\scripts\run-tests-ministack.ps1

# Validación completa (sin credenciales AWS)
.\scripts\validate-terraform.ps1
```
