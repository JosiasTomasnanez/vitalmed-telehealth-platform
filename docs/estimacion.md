# Estimación de Costos de Infraestructura AWS - VitalMed Telesalud

Este documento presenta el análisis y la consolidación de costos de la infraestructura cloud para **VitalMed**, basado en la estimación de servicios realizada en AWS Pricing Calculator. Se evalúa el costo base unitario y la proyección consolidada para la operación multipaís (**Argentina 🇦🇷, Chile 🇨🇱, Colombia 🇨🇴 y México 🇲🇽**).

---

## 1. Resumen de la Estimación Base (1 Cuenta / País)

La estimación base cargada en la calculadora totaliza **$1.409,02 USD / mes** agrupada en 7 dominios de servicio:

| Grupo de Uso | Servicios Incluidos | Costo Base Mensual (USD) |
| :--- | :--- | :--- |
| **Datos** | Amazon Aurora Serverless v2 (PostgreSQL), Amazon ElastiCache (Redis Serverless), Amazon S3, AWS Backup y Data Transfer de datos. | **$724,11** |
| **Media** | Amazon Chime SDK . | **$272,00** |
| **Cómputo** | Amazon ECS en AWS Fargate, AWS Lambda (ARM) y Data Transfer Out. | **$226,15** |
| **Observabilidad** | CloudWatch (Database Insights, Métricas, Logs, Alarmas, Dashboards), GuardDuty, Config, Security Hub, X-Ray, CloudTrail y SNS. | **$137,35** |
| **Red** | AWS WAF (Web ACL, Reglas administradas y peticiones), Amazon CloudFront (Sudamérica y Norteamérica) y Amazon Route 53 (DNS y Health Checks). | **$42,10** |
| **Organización** | AWS KMS (Claves maestras CMK y peticiones) y AWS Secrets Manager (5 secretos y llamadas API). | **$6,25** |
| **Integración Asincrónica** | Amazon SQS (Colas Standard y FIFO). | **$1,05** |

**Total Estimación Base :** $1.409,02 USD / mes

---

## 2. Análisis de Replicabilidad y Redundancia Multipaís

Para cumplir con las regulaciones de salud locales (tipo HIPAA y aislamiento de Historias Clínicas Electrónicas), la arquitectura se divide en dos categorías:

1. **Servicios Replicados por País (Multiplicados por 4):**
   * Toda la capa de **Datos** (Aurora, ElastiCache, S3, Backup).
   * La capa de **Cómputo** (ECS Fargate, Lambda) e **Integración Asincrónica** (SQS).
   * La suite de **Observabilidad y Seguridad** (CloudWatch, GuardDuty, Config, Security Hub, X-Ray, CloudTrail, SNS, Secrets Manager, KMS y WAF/Route 53).
   * **Subtotal Replicado por País:** $1.409,02 - $272,00 (Media) = **$1.137,02 USD / mes**.

2. **Servicios Transversales / Globales:**
   * **Amazon Chime SDK (Media):** Opera en el Edge global bajo demanda. El costo depende de la cantidad total de minutos de consulta de toda la empresa sin requerir infraestructura fija duplicada ($272,00 USD / mes presupuestados para la demanda global inicial).
   * **AWS Organizations / CloudFront:** Gobernanza centralizada y distribución Anycast con capa gratuita consolidada.

---

## 3. Proyección del Costo Total de la Plataforma (4 Países)

| Componente | Cálculo | Total Mensual (USD) |
| :--- | :--- | :--- |
| **Infraestructura Replicada (4 Cuentas)** | $1.137,02 \times 4$ | **$4.548,08** |
| **Servicio de Telemedicina Centralizado (Chime SDK)** | $272,00 \times 1$ | **$272,00** |

**Total General Estimado :**  $4.820,08 USD / mes

---

## 4. Conclusiones y Excelencia Operativa

* **Aislamiento y Blast Radius:** La duplicación de los entornos de datos y cómputo garantiza cumplimiento normativo estricto y asegura que un incidente o pico estacional en un país no degrade la operación de los demás.
* **Mantenibilidad:** Toda la infraestructura replicada se gestiona mediante módulos unificados de Terraform (IaC) y servicios serverless/administrados (Fargate, Aurora, Backup), manteniendo la carga operativa dentro de la capacidad de un equipo reducido.