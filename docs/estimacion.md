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
   * **Subtotal Replicado por País:** 724,11 (Datos) + 226,15 (Computo) + 1,05 (Integración Asincronica) = **$ 951,31 / mes**.

2. **Servicios Transversales / Globales:**
   * **Amazon Chime SDK (Media):** Opera en el Edge global bajo demanda. El costo depende de la cantidad total de minutos de consulta de toda la empresa sin requerir infraestructura fija duplicada ($272,00 USD / mes presupuestados para la demanda global inicial).
   * **AWS Organizations / CloudFront:** Gobernanza centralizada y distribución Anycast con capa gratuita consolidada.
   * **Observabilidad y Seguridad** (CloudWatch, GuardDuty, Config, Security Hub, X-Ray, CloudTrail, SNS, Secrets Manager, KMS y WAF/Route 53).
   * **Subtotal Global:** 272,00 (Media) + 137,35 (Observabilidad) + 42,10 (Red) + 6,25 (Organización) = **$ 457,7 / mes**.

3. **Cuenta de Preproduccion:**
   * Todo el stack de servicios es replicado en una cuenta compartida por todos los paises para realizar pruebas previas al paso a produccion.
   * **Subtotal por parte de preproduccion:** **$ 951,31 USD / mes**

---

## 3. Proyección del Costo Total de la Plataforma (4 Países + Preproduccion)

| Componente | Cálculo | Total Mensual (USD) |
| :--- | :--- | :--- |
| **Infraestructura Replicada (4 Cuentas + preproduccion)** | $951,31 \times 5$ | **$4.756,55** |
| **Servicio Transversales / Globales** | $457,7 \times 1$ | **$457,7** |

**Total General Estimado :**  $5.214,25 USD / mes

---

## 4. Analisis del costo en un mes estacional (x4)

Frente al aumento de trafico por un mes estacional, algunos servicios determinaran un aumento significativo de su consumo o de su potencia por lo que la estimacion junto con este aumento seria de **$3066,54 USD / mes** agrupada en los 7 dominios de servicio previamente analizados:

| Grupo de Uso | Servicios Incluidos | Costo Base Mensual (USD) |
| :--- | :--- | :--- |
| **Datos** | Amazon Aurora Serverless v2 (PostgreSQL), Amazon ElastiCache (Redis Serverless), Amazon S3, AWS Backup y Data Transfer de datos. | **$1020,33** |
| **Media** | Amazon Chime SDK . | **$1088,00** |
| **Cómputo** | Amazon ECS en AWS Fargate, AWS Lambda (ARM) y Data Transfer Out. | **$489,35** |
| **Observabilidad** | CloudWatch (Database Insights, Métricas, Logs, Alarmas, Dashboards), GuardDuty, Config, Security Hub, X-Ray, CloudTrail y SNS. | **$317,87** |
| **Red** | AWS WAF (Web ACL, Reglas administradas y peticiones), Amazon CloudFront (Sudamérica y Norteamérica) y Amazon Route 53 (DNS y Health Checks). | **$130,80** |
| **Organización** | AWS KMS (Claves maestras CMK y peticiones) y AWS Secrets Manager (5 secretos y llamadas API). | **$16,00** |
| **Integración Asincrónica** | Amazon SQS (Colas Standard y FIFO). | **$4.20** |

**Total Estimación Base con el aumento estacional :** $3066,54 USD / mes*

| Componente | Cálculo | Total Mensual (USD) |
| :--- | :--- | :--- |
| **Infraestructura Replicada (4 Cuentas)** | $1.513.88 \times 4$ | **$6.055,52** |
| **Servicio Transversales / Globales** | $1.552,67 \times 1$ | **$1.552,67** |

**Total General Estimado con el aumento estacional:**  $7.608,19 USD / mes

---

## 5. Conclusiones y Excelencia Operativa

* **Eficiencia de Costos y Autoescalado Dinámico:** La arquitectura evita el sobreaprovisionamiento de instancias fijas y bases de datos sobredimensionadas. Gracias a **ECS Fargate (ARM/Graviton)** y **Aurora Serverless v2**, el cómputo y la memoria se ajustan automáticamente según la demanda (escalando ante picos de atención de 7 a 23 h y desescalandose al mínimo en horarios no pico), reduciendo el costo mensual de infraestructura en más de un 40% frente a esquemas estáticos tradicionales.
* **Aislamiento y Blast Radius:** La duplicación de los entornos de datos y cómputo garantiza cumplimiento normativo estricto y asegura que un incidente o pico estacional en un país no degrade la operación de los demás.
* **Mantenibilidad:** Toda la infraestructura replicada se gestiona mediante módulos unificados de Terraform (IaC) y servicios serverless/administrados (Fargate, Aurora, Backup), manteniendo la carga operativa dentro de la capacidad de un equipo reducido.
