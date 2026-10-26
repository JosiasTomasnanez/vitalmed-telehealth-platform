# VitalMed Telesalud: infraestructura AWS multi-cuenta con Terraform

[![IaC-Terraform](https://img.shields.io/badge/IaC-Terraform-purple?logo=terraform)](https://www.terraform.io/)
[![AWS Well-Architected](https://img.shields.io/badge/AWS-Well--Architected-orange?logo=amazon-aws)](https://aws.amazon.com/architecture/well-architected/)

Trabajo práctico grupal de la **Diplomatura en DevOps (FCEFyN, UNC)**, con foco en el pilar de **Excelencia Operativa** del AWS Well-Architected Framework.

El caso es una empresa ficticia de telemedicina con 180.000 pacientes y 4.500 profesionales en **Argentina, Chile, Colombia y México**. Tiene picos estacionales de hasta 4x y datos de salud que cada país exige mantener aislados.

![Arquitectura cloud](docs/data/Diagrama%20de%20Arquitectura%20Cloud.jpg)

## Decisiones de arquitectura

1. **Una cuenta AWS por país** (AWS Organizations) en lugar de multi-región. El aislamiento regulatorio se logra con límites de cuenta, bases y claves KMS propias, sin el costo ni la complejidad de replicar entre regiones. Todo corre en `us-east-1`, más una cuenta **preprod** global y una **shared** para el state.
2. **Cómputo sin servidores que administrar**: backend en **ECS Fargate** detrás de un **ALB**, con autoscaling para absorber los picos. Las tareas asíncronas (recetas, notificaciones) pasan por **SQS + Lambda**.
3. **Datos**: **Aurora PostgreSQL Serverless v2**, que escala en ACUs según la demanda, y **S3** cifrado con **KMS** por país para estudios y archivos.
4. **Borde**: **CloudFront + S3** para el frontend, **WAF**, **Route 53** y certificados **ACM**.
5. **Videollamadas** con Amazon Chime SDK. Al ser un servicio solo de API, en Terraform se resuelve con los permisos IAM del task role del backend.

## Qué está implementado en Terraform

| Componente | Recursos | Ubicación |
|---|---|---|
| Organización | `aws_organizations_organization`, 4 OUs, cuentas por país, service access para CloudTrail y Security Hub | `terraform/org/` |
| State remoto | Bucket S3 con versionado, cifrado y bloqueo nativo (`use_lockfile`, sin DynamoDB) | `terraform/global/state-backend/` |
| `network` | VPC, subredes públicas, privadas y de datos en 2 AZ, IGW, NAT Gateway, route tables | `terraform/modules/network/` |
| `compute` | ECR, ECS cluster y servicio Fargate, ALB + target group + listeners, security groups, autoscaling | `terraform/modules/compute/` |
| `data` | Aurora PostgreSQL Serverless v2, KMS key por país, S3 con lifecycle y bloqueo de acceso público, Secrets Manager | `terraform/modules/data/` |
| `async` | SQS (con DLQ) y Lambda con event source mapping | `terraform/modules/async/` |
| `edge` / `edge-cert` / `frontend-bucket` | CloudFront con OAC, WAFv2, Route 53, ACM, bucket del frontend | `terraform/modules/edge*/`, `terraform/modules/frontend-bucket/` |
| Entornos | Composición de módulos por país (`ar`, `cl`, `co`, `mx`) y `preprod`, versionados con `?ref=` | `terraform/environments/` |

### Diseño propuesto, todavía no implementado en código

Estos servicios forman parte del diseño del informe pero no tienen recursos en el repo:

- AWS Control Tower y SCPs. La creación de cuentas que haría su Account Factory está resuelta con Terraform en `terraform/org/`.
- IAM Identity Center.
- ElastiCache.
- AWS X-Ray.
- AWS Backup.

## Calidad y pruebas

- **33 tests** con `terraform test` para 5 módulos (`network`, `compute`, `data`, `edge`, `async`), en `terraform/modules/*/tests/`.
- **Ejecución local contra emuladores**: `scripts/run-tests-ministack.sh` y `scripts/run-tests-localstack.sh` inyectan un provider override temporal que apunta al emulador y lo borran al terminar.
- **CI en cada PR** (`.github/workflows/terraform-ci-cd.yml`): `terraform fmt` y `validate`, **TFLint**, **Checkov** (en modo informativo, `soft_fail`) y `terraform test`. Un job `ci-status` consolida el resultado y falla si no pasan validate, TFLint o los tests.
- **Despliegue**: los jobs de deploy del pipeline son **simulados**, porque el TP no contemplaba cuentas AWS reales. Muestran el orden de aplicación (state backend → organización → cuentas por país → preprod), y el procedimiento real está documentado en el runbook.

### Validación rápida local

```bash
cd terraform/modules/network
terraform init -backend=false
terraform validate
terraform test
```

## Estructura

```text
.
├── .github/workflows/      # CI de Terraform (fmt, validate, TFLint, Checkov, tests)
├── docs/                   # Informe por área, diagramas, runbooks y estimación de costos
├── scripts/                # Emuladores (MiniStack/LocalStack) y ejecución de tests
└── terraform/
    ├── global/state-backend/
    ├── org/                # AWS Organizations y cuentas
    ├── modules/            # network, compute, data, async, edge, edge-cert, frontend-bucket
    ├── environments/       # ar, cl, co, mx (prod) y preprod
    └── tests/              # Providers de MiniStack/LocalStack para tests locales
```

## Documentación

- [Runbook de despliegue](docs/runbook.md): prerrequisitos, orden de aplicación, rollback y validaciones.
- [Runbook de operaciones](docs/runbook-operaciones.md).
- [Estimación de costos](docs/estimacion.md) y [calculadora de AWS](docs/calculadora-aws.json).
- [Informe web por área](https://josiastomasnanez.github.io/vitalmed-telehealth-platform/): negocio, VPC, cómputo, persistencia, seguridad y observabilidad.

## Equipo (Grupo 9)

Josias Tomas Ñañez, Maximiliano Cravero, Gabriel Oliva, Jerónimo Massaro y Lautaro Castro.

Josias armó el pipeline de CI, la suite de 33 tests de Terraform, los scripts de testing con MiniStack/LocalStack y el runbook de despliegue.
