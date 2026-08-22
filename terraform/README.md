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

## Por qué algunos servicios quedan "solo diseño"

- **Control Tower**: se aprovisiona mediante un flujo guiado propio (landing zone) y la mayoría de sus recursos no tienen recurso de Terraform nativo — se administra desde la consola o con el SDK/CLI de Control Tower, no con `terraform apply`. El módulo `org/` reemplaza su función central (Organizations + OUs + account factory) con recursos que sí son 100% Terraform.
- **SCPs**: una vez con la estructura de OUs de `org/`, se agregarían como `aws_organizations_policy` adjuntas a cada OU de país (ej: "deny si la región no es us-east-1", "deny a servicios fuera del stack aprobado"). No se codean todavía porque conviene definir primero qué acciones se quieren permitir/denegar por país según la normativa local (ej. requisitos de residencia de datos de salud en cada país).
- **IAM Identity Center**: requiere estar habilitado a nivel Organization (ya lo dejamos habilitado como servicio en `org/organization.tf`) y luego configurar un Identity Source (AD, o el store nativo) — ese paso inicial no es manejable por Terraform, pero los Permission Sets posteriores sí (`aws_ssoadmin_permission_set`).
- **Amazon Chime SDK**: es consumido vía SDK desde el propio backend (se crean "meetings" dinámicamente en runtime, no son recursos declarativos de infraestructura). El único artefacto de Terraform relacionado es el permiso IAM (`chime:CreateMeeting`, etc.) que ya está adjunto al `task_role` de ECS en cada environment.
- **Security Hub**: se puede activar con `aws_securityhub_account`, pero requiere antes tener GuardDuty/Config habilitados en cada cuenta para que aporte valor real — queda documentado como el siguiente paso natural después de tener las 9 cuentas desplegadas.
- **CloudWatch / X-Ray**: CloudWatch ya está parcialmente codeado (Container Insights en ECS, log groups por microservicio, logs de Postgres de Aurora). X-Ray requeriría instrumentar el código de cada microservicio (SDK de X-Ray en la app), por eso queda fuera del alcance de infraestructura pura.
- **CloudTrail**: se activaría a nivel Organization (trail organizacional único que registra las 9 cuentas) apuntando al bucket de logs de la cuenta shared — es el paso natural siguiente a tener `org/` aplicado.

## Estructura del repo

> Esta carpeta se llama `infra/` acá, pero en tu repositorio Git corresponde a `terraform/` — los `source` de los módulos ya apuntan a `terraform/modules/<nombre>` dentro del repo.

```
infra/                             # == terraform/ en el repositorio Git
├── global/state-backend/         # bootstrap: bucket S3 con locking nativo (use_lockfile)
├── org/                          # cuenta management: Organizations + account factory
├── modules/                      # cada uno se referencia por Git+tag desde environments/, no por path local
│   ├── network/                  # VPC, subnets, NAT, route tables
│   ├── compute/                  # ALB, ECS Fargate, ECR
│   ├── data/                     # Aurora Serverless v2, S3+KMS, Secrets Manager
│   ├── async/                    # SQS, Lambda
│   ├── edge-cert/                # ACM (separado para evitar ciclo compute<->edge)
│   ├── edge/                     # CloudFront, WAF, Route 53
│   └── frontend-bucket/          # bucket S3 privado para el build estático, servido por CloudFront
└── environments/
    ├── ar/{prod,preprod}/
    ├── cl/{prod,preprod}/
    ├── co/{prod,preprod}/
    └── mx/{prod,preprod}/        # cada uno instancia los 7 módulos vía source = "git::...?ref=v1.0"
```
