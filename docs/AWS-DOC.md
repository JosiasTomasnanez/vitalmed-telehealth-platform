# VitalMed Telesalud — Informe de Herramientas AWS

**Grupo 10 · Diplomatura DevOps · Pilar: Excelencia Operativa**

Este documento detalla cada servicio AWS elegido para la arquitectura de VitalMed, explicando su función puntual dentro del proyecto. Complementa la Parte 1 de la consigna ("Diseño de la solución — Definición de Servicios") y la pestaña 5 del panel de gobierno de IAM/Organizations (que cubre en detalle solo la parte de cuentas, roles y accesos).

---

## Supuesto explícito: arquitectura mono-región

AWS no tiene región propia en Argentina, Chile ni Colombia (la más cercana es `sa-east-1`, São Paulo). México sí cuenta con región propia desde enero de 2025 (`mx-central-1`, Querétaro). Desplegar en múltiples regiones agregaría latencia inter-región, replicación de KMS multirregión y costos de transferencia de datos que un equipo de 12 personas no puede sostener de forma realista.

**Decisión:** se descarta la multirregión y se despliega todo en **una sola región, `us-east-1`**. La separación regulatoria por país que exige el caso (equivalente a HIPAA) se resuelve exclusivamente mediante **aislamiento lógico por cuenta de AWS** (una cuenta independiente por país dentro de Organizations, con su propia base de datos, su propia llave KMS y sus propios permisos), no mediante aislamiento geográfico.

**Trade-off aceptado:** un incidente regional de AWS en `us-east-1` afectaría a los cuatro países simultáneamente. Se acepta ese riesgo a cambio de menor costo y complejidad operativa, coherente con el pilar de Excelencia Operativa y el tamaño del equipo.

---

## 🌐 Red y Borde

| Servicio | Para qué sirve en VitalMed |
|---|---|
| **Amazon Route 53** | DNS de la plataforma. Resuelve el dominio público hacia CloudFront y permite health checks para failover si algún componente cae. |
| **Amazon CloudFront** | CDN que sirve el frontend web/móvil y cachea contenido estático cerca del paciente — clave para la baja latencia pedida en LatAm. |
| **AWS WAF** | Filtra SQL injection, bots y patrones de DDoS antes de que la petición llegue al ALB. Importante porque se manejan datos de salud expuestos a internet. |
| **AWS Certificate Manager (ACM)** | Certificados TLS/SSL gestionados y renovados automáticamente, sin rotación manual. |

## 🏢 Organización, Identidad y Gobierno

| Servicio | Para qué sirve en VitalMed |
|---|---|
| **AWS Organizations (multi-cuenta)** | Separa Argentina, Chile, Colombia y México en cuentas independientes — el mecanismo real de aislamiento regulatorio, dado que no se usa multirregión. |
| **AWS Control Tower** | Automatiza el alta de cuentas nuevas con guardrails ya aplicados (landing zone). Responde al requisito de sumar un 5º país sin rediseñar: la cuenta se aprovisiona desde el Account Factory. |
| **SCPs (Service Control Policies)** | Políticas a nivel Organization/OU: bloquean crear recursos fuera de `us-east-1`, impiden desactivar CloudTrail y prohíben usuarios IAM con llaves estáticas. |
| **IAM Identity Center (AWS SSO)** | Único punto de login para las 12 personas del equipo, con permission sets por rol (DevOps, Developer, Auditor) asignados por cuenta — no usuarios sueltos por cuenta. |
| **IAM (Roles y Políticas)** | Roles de ejecución/tarea diferenciados en ECS, roles cross-account para operaciones centralizadas, y permission boundaries para que nadie escale privilegios más allá de lo que permite la SCP de su cuenta. |
| **AWS Secrets Manager** | Credenciales de base de datos y API keys de terceros (aseguradoras), rotadas automáticamente y nunca hardcodeadas en el repo. |
| **AWS KMS** | Cada cuenta de país tiene su propia Customer Managed Key. Todo lo guardado en Aurora, DynamoDB y S3 se cifra con la llave de ese país. |

## ⚙️ Cómputo y Backend

| Servicio | Para qué sirve en VitalMed |
|---|---|
| **Application Load Balancer (ALB)** | Recibe el tráfico de la VPC y lo enruta al microservicio correcto (turnos, HCE, facturación) según el path de la API. |
| **Amazon ECS + AWS Fargate** | Corre los microservicios en contenedores sin administrar EC2 ni hacer patching de SO. Escala automáticamente ante los picos de temporada invernal/vacunación. |
| **Amazon ECR** | Registro privado de imágenes Docker. El pipeline de CI construye la imagen y la sube acá; ECS la descarga para desplegar. |
| **AWS Lambda** | Procesos cortos y asíncronos (generar el PDF de una receta, enviar una notificación) disparados por eventos de SQS, sin mantener un contenedor corriendo 24/7. |

## 🔄 Integración Asíncrona

| Servicio | Para qué sirve en VitalMed |
|---|---|
| **Amazon SQS** | Desacopla al backend de tareas que no necesitan respuesta inmediata (emitir receta, enviar mail). Si Lambda se demora o falla, el mensaje no se pierde y se reintenta. |

## 🗄️ Datos y Archivos

| Servicio | Para qué sirve en VitalMed |
|---|---|
| **Amazon Aurora Serverless v2 (Multi-AZ)** | Base de datos relacional para la Historia Clínica Electrónica. Ajusta capacidad sola según demanda y replica en tiempo real entre zonas de disponibilidad. |
| **Amazon ElastiCache** | Sesiones de usuario y estados temporales de facturación, con latencia de milisegundos y sin servidor que administrar. |
| **Amazon S3** | Resultados de laboratorio, recetas firmadas y grabaciones de consultas (cuando el paciente autoriza), cifrados con la KMS del país correspondiente. |

## 📹 Media

| Servicio | Para qué sirve en VitalMed |
|---|---|
| **Amazon Chime SDK** | Provee las videoconsultas en vivo médico-paciente. El video WebRTC viaja directo entre los dos extremos, sin pasar por la VPC ni cargar a los contenedores de ECS. |

## 📜 Observabilidad, Auditoría y Cumplimiento

| Servicio | Para qué sirve en VitalMed |
|---|---|
| **Amazon CloudWatch** | Logs centralizados de todos los microservicios y métricas (CPU, errores 500) que disparan las alarmas. |
| **AWS X-Ray** | Traza una request de punta a punta (CloudFront → ALB → ECS → Aurora), mostrando en qué tramo se generó la demora. |
| **Amazon SNS** | Envía la alerta desde CloudWatch al Slack/PagerDuty del equipo de guardia cuando hay riesgo de que un paciente pierda su consulta. |
| **AWS CloudTrail** | Audita cada acceso a infraestructura y a datos ("qué rol leyó la tabla de HCE y cuándo") — lo que exige cualquier auditoría tipo HIPAA. |
| **AWS Config + Conformance Packs** | Corre reglas de compliance en las 4 cuentas (ej. "ningún bucket S3 sin cifrado") y avisa si algo se desvía del estándar, sin revisión manual cuenta por cuenta. |
| **Amazon GuardDuty + AWS Security Hub** | Detección de amenazas y tablero único de postura de seguridad, agregando las 4 cuentas de país desde la cuenta Security del Core OU. |
| **AWS Backup** | Plan de backup centralizado con retención definida por política para Aurora, ElastiCache y S3, en vez de backups sueltos por servicio. |
| **AWS Systems Manager – Parameter Store** | Configuración no sensible (flags, endpoints) separada de Secrets Manager, para no depender de un único servicio para toda la config. |

## 🔧 CI/CD (fuera de AWS)

| Herramienta | Para qué sirve en VitalMed |
|---|---|
| **GitHub Actions** (runners a definir, posiblemente self-hosted) | Build, test y push de las imágenes Docker de cada microservicio. Se eligió por costo frente a CodePipeline/CodeBuild nativos de AWS. |
| **Rol IAM vía OIDC** | GitHub Actions asume un rol temporal en la cuenta correspondiente para pushear a ECR y actualizar el servicio de ECS, sin guardar access keys estáticas como secret del repo. |

