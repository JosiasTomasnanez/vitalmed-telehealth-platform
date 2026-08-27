# 🩺 VitalMed Telesalud — Infraestructura en AWS & IaC

[![AWS Well-Architected](https://img.shields.io/badge/AWS-Well--Architected-orange?logo=amazon-aws)](https://aws.amazon.com/architecture/well-architected/)
[![IaC-Terraform](https://img.shields.io/badge/IaC-Terraform-purple?logo=terraform)](https://www.terraform.io/)
[![DevOps-Group](https://img.shields.io/badge/Grupo-9-blue)](#-equipo-de-desarrollo)

> **Solución de Infraestructura como Código (IaC) para la escala continental de VitalMed Telesalud, diseñada bajo el pilar de Excelencia Operativa para conectar a +180,000 pacientes y 4,500 profesionales de la salud en Argentina, Chile, Colombia y México.**

---

## 📌 Contexto & El Desafío del Cliente

**VitalMed Telesalud** enfrenta un reto clásico de crecimiento acelerado en Latinoamérica: **escalar la operación regional quadruplicando la capacidad durante picos estacionales (otoño/invierno), garantizando cumplimiento regulatorio de datos de salud (HIPAA-equivalent) y disponibilidad continua (7:00 a 23:00 hs), todo esto gestionado por un equipo reducido de 12 personas.**


```

+-----------------------------------------------------------------------------------+
|                           EL DESAFÍO VITALMED                                     |
+------------------------------------+----------------------------------------------+
| 👥 180,000+ Pacientes Activos      | 📈 Picos 4x por campañas/estaciones          |
| 👨‍⚕️ 4,500 Profesionales de la Salud | 🌐 Operación en 4 países (AR, CL, CO, MX)    |
| 👨‍💻 Equipo de IT: ~12 personas      | 🔐 Datos Médicos Sensibles (Ley HIPAA/Local) |
+------------------------------------+----------------------------------------------+

```

---

## 🚀 Nuestra Solución: Arquitectura Serverless & Multi-Cuenta

Inspirados en el pilar de **Excelencia Operativa del AWS Well-Architected Framework**, diseñamos una arquitectura resiliente, automatizada e impulsada por **Serverless**, minimizando el trabajo manual y eliminando la administración de servidores físicos o máquinas virtuales.

<Image src="image_agent_tag_1" alt="Diagrama conceptual de la arquitectura AWS para VitalMed" caption="Arquitectura lógica multi-cuenta y desacoplada en AWS" />

### 💡 Decisiones Estratégicas Clave

1. **Aislamiento Regulatorio Lógico (Multi-Cuenta con AWS Organizations):**
   * *Desafío:* Separar estrictamente los datos de salud por normativa en Argentina, Chile, Colombia y México.
   * *Decisión:* En lugar de desplegar en múltiples regiones con costos de transferencia prohibitivos y alta complejidad de gestión, centralizamos en la región `us-east-1` utilizando **cuentas de AWS totalmente aisladas por país**.
   * *Resultado:* Cada país cuenta con su propia base de datos, sus llaves de cifrado en **AWS KMS** y un límite infranqueable de permisos.

2. **Cómputo Serverless y Alta Disponibilidad (ECS Fargate + Lambda):**
   * Eliminamos la administración de parches o SO corriendo contenedores en **Amazon ECS con AWS Fargate**.
   * Absorción automática de picos estacionales (pases de 1x a 4x de tráfico) mediante Auto Scaling sin sobre-provisionar infraestructura en época baja.

3. **Telemedicina de Ultra-Baja Latencia (Amazon Chime SDK):**
   * La transmisión de video WebRTC fluye directamente entre médico y paciente a través de los Edge Locations globales de AWS. **Cero carga de video sobre los contenedores del backend.**

4. **Escalabilidad para un Quinto País sin Rediseño:**
   * Utilizando **AWS Control Tower (Account Factory)**, el onboarding de un nuevo país se reduce a aprovisionar un nuevo módulo de Terraform en minutos.

---

## 🛠️ Stack Tecnológico & Servicios AWS

| Capa | Servicios Seleccionados | Justificación de Negocio / Operativa |
| :--- | :--- | :--- |
| **Borde y Seguridad** | Route 53, CloudFront, AWS WAF, ACM | Carga ultra rápida del frontend, certificados SSL automáticos y mitigación de ataques web/DDoS. |
| **Gobierno y Control** | AWS Organizations, Control Tower, SCPs, IAM Identity Center | Gobernanza centralizada multi-cuenta, acceso unificado (SSO) y reglas globales de cumplimiento. |
| **Backend & APIs** | ALB, Amazon ECS Fargate, Amazon ECR | Microservicios (Turnos, HCE, Facturación) aislados en contenedores con autoscaling. |
| **Procesos Asíncronos** | Amazon SQS, AWS Lambda | Procesamiento de recetas y notificaciones desvinculado del hilo principal del backend. |
| **Persistencia de Datos**| Aurora Serverless v2, ElastiCache, S3, Cloud Backup | Base de datos relacional para HCE que escala automáticamente, almacenamiento masivo de estudios cifrado con KMS por país. |
| **Videollamadas** | Amazon Chime SDK | Consultas médicas en vivo sin sobrecargar la red interna. |
| **Observabilidad & Auditoría**| CloudWatch, AWS X-Ray, CloudTrail, Security Hub | Trazabilidad de accesos (quién vio qué HCE), métricas en vivo y alertas en Slack/PagerDuty antes de impactar la atención. |

---

## 📈 Análisis de Costos (Habitual vs. Pico Estacional)

Gracias al modelo **Pay-As-You-Go** e infraestructura Serverless (*Aurora Serverless v2 + Fargate*), VitalMed no paga por capacidad ociosa durante los meses de baja demanda.

| Escenario | Estrategia de Cómputo / Base de Datos | Impacto de Costo Aproximado |
| :--- | :--- | :--- |
| **Operación Habitual** | Fargate y Aurora corriendo a capacidad base mínima (Mínimos ACU). | Base operativa optimizada |
| **Pico Estacional (4x)** | Escalado automático horizontal de tareas ECS + Auto-scale de ACUs en Aurora. | Incremento temporal adaptado a la demanda real |

---

## 📂 Estructura del Repositorio

El repositorio está organizado para permitir una validación transparente y modular con Terraform:

```text
.
├── .github/workflows/       # Pipelines de CI/CD para prueba y validación de IaC
├── docs/                    # Documentación técnica extendida y Diagramas
│   ├── arquitectura.png    # Diagrama de arquitectura de AWS
│   ├── analisis-costos.pdf # Reporte exportado de AWS Calculator
│   └── runbook.md          # Manual de operaciones y guía de despliegue
├── terraform/               # Código de Infraestructura como Código
│   ├── modules/            # Módulos reutilizables (VPC, ECS, Aurora, KMS)
│   ├── environments/       # Configuraciones por país (AR, CL, CO, MX)
│   └── tests/              # Pruebas integradas de Terraform (terraform test)
└── README.md                # Presentación principal del proyecto

```

---

## ⚡ Validación Rápida de Código (Local)

El proyecto está preparado para ser evaluado sin necesidad de aprovisionar infraestructura real en AWS:

```bash
# 1. Formato de código
terraform fmt -check

# 2. Inicialización del backend simulado
terraform init -backend=false

# 3. Validación sintáctica y lógica
terraform validate

# 4. Ejecución de suite de pruebas integradas
terraform test

```

---

## 📖 Documentación Complementaria

* 📋 **[Runbook de Despliegue](https://www.google.com/search?q=./docs/runbook.md):** Pasos detallados de configuración, orden de despliegue, rollback y validaciones.
* 🛡️ **[Informe de Herramientas AWS y Cuentas](https://josiastomasnanez.github.io/vitalmed-telehealth-platform/):** Justificación en profundidad de los servicios elegidos.

---

## 👥 Equipo de Desarrollo — Grupo 9

Proyecto desarrollado dentro del marco de la **Diplomatura DevOps**, enfocado en la aplicación práctica del **AWS Well-Architected Framework (Excelencia Operativa)**.


```
