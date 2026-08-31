# Runbook de Despliegue — Resumen Ejecutivo

**Grupo 9 · Diplomatura DevOps · Pilar: Excelencia Operativa**

> Versión de una página para la defensa técnica. El detalle completo está en [runbook.md](./runbook.md) y su [Anexo de Operaciones](./runbook-operaciones.md).

## 1. Prerrequisitos y permisos

- **Herramientas**: Terraform >= 1.10, AWS CLI 2.x, GitHub CLI, Docker Desktop (para MiniStack).
- **Cuentas**: 7 en total — 1 management + 4 producción (`ar`, `cl`, `co`, `mx`) + 1 preprod global + 1 shared (state/logging).
- **Permisos**: rol de despliegue con acceso a `organizations`, `s3`, `ecs`, `rds`, `lambda`, `sqs`, `kms`, `secretsmanager`, `cloudfront`, `wafv2`, `route53`, `acm`, `cloudwatch`, `logs`, `ecr` (ver §1.2).

## 2. Configuración de variables

- Por entorno, solo dos variables: `account_id` (cuenta destino) y `zona_route53_id` (dominio raíz).
- `pais`/`entorno` se pasan como literales; el CIDR de la VPC va inline en `main.tf`.
- Backend **S3 con locking nativo** `use_lockfile = true` (Terraform >= 1.10, **sin DynamoDB**).

## 3. Orden de despliegue

1. `terraform/global/state-backend` — bootstrap del bucket, backend local (una sola vez).
2. `terraform/org` — Organizations + account factory (4 prod, preprod, shared).
3. `terraform/environments/<pais>/prod` — un país por vez (`ar`, `cl`, `co`, `mx`).
4. `terraform/environments/preprod` — preproducción global, una sola vez.

## 4. Validaciones

- **Previas**: `terraform fmt -check`, `init -backend=false`, `validate`, `test` + checks de seguridad (sin credenciales hardcodeadas, KMS/S3 cifrados) y arquitectura (Serverless v2, Fargate, subnets de datos aisladas).
- **Posteriores**: VPC/Aurora/ECS/CloudFront presentes, health check del ALB, conectividad a Aurora, S3 no público.

## 5. Estrategia de rollback

- **Manual**: `git revert` del commit problemático + `terraform apply`; el state se restaura vía versioning del bucket S3.
- **CI/CD**: revertir el commit y dejar que el pipeline re-aplique. Producción solo corre si preprod terminó OK (`needs: [deploy-preprod]`).

## 6. Pruebas de Excelencia Operativa

- **Observabilidad**: log groups y alarmas CloudWatch.
- **Seguridad**: buckets no públicos, Aurora cifrado, credenciales en Secrets Manager.
- **Resiliencia**: `force-new-deployment` (chaos), fallover de Aurora.
- **Auto-scaling**: carga simulada y verificación de escalado ECS/Aurora.

## 7. Limitaciones que requieren cuenta real

- `terraform apply`/`import` y la CLI necesitan credenciales y cuotas reales.
- **Solo diseño** (no provisionados por Terraform): CloudTrail, GuardDuty, X-Ray, Security Hub.
- AWS Academy no permite Organizations/Control Tower/Chime SDK → workaround con una sola cuenta y aislamiento por VPC.

---

**Última actualización**: 2026-08-31 · **Versión**: 2.1 · **Autor**: Grupo 9 — Diplomatura DevOps
