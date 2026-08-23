# Datos y archivos

---

## 1. Amazon Aurora Serverless v2 (Multi-AZ)

### ¿Qué es y qué función cumple?

Es la base de datos relacional transaccional (RDBMS) principal de la plataforma. Almacena todos los datos estructurados críticos:
* Historias Clínicas Electrónicas (HCE) y registros de consultas.
* Gestión de agendas, turnos médicos y perfiles de usuarios/profesionales.
* Transacciones de facturación y liquidación con aseguradoras médicas.

### ¿Por qué es necesario para el proyecto?

* **Consistencia e Integridad ACID:** Los registros médicos y transacciones financieras exigen estricta integridad relacional y soporte transaccional que evite inconsistencias o estados corruptos.
* **Escalabilidad Elástica sin Intervención Manual:** Gracias al motor Serverless v2, la capacidad de cómputo escala instantáneamente (en incrementos de ACUs) ante los picos de invierno o campañas de vacunación (hasta 4x consultas), contrayéndose en horario nocturno para optimizar costos de forma automática.
* **Alta Disponibilidad Multi-AZ:** Despliegue con réplica de lectura activa y conmutación (*failover*) automática en menos de 30 segundos, asegurando el SLA de **cero caídas** durante el horario de atención médica (7:00 a 23:00 h).
* **Integración con RDS Proxy:** Agrupa y reutiliza conexiones eficientemente para absorber las conexiones concurrentes de los microservicios en ECS Fargate y funciones Lambda.

---

## 2. Amazon ElastiCache

### ¿Qué es y qué función cumple?

Es la capa de base de datos en memoria RAM (In-Memory Data Store) de baja latencia (<10 ms) desplegada en la subred privada de la VPC.

### ¿Por qué es necesario para el proyecto?

* **Gestión Rápida de Sesiones Médicas:** Mantiene las sesiones activas y tokens JWT de los 180,000 pacientes y 4,500 profesionales, permitiendo validar autenticaciones a velocidad submilisegundo sin consultar a la base de datos relacional.
* **Alivio de Carga Transaccional (Read-Heavy Caching):** Almacena en caché catálogos de cobertura médica, estados de disponibilidad de especialistas y consultas frecuentes, reduciendo la latencia de respuesta de más de 500 ms a menos de 10 ms.
* **Control de Concurrencia y Bloqueos Distribuidos:** Evita colisiones o duplicación de reservas cuando múltiples pacientes intentan agendar el mismo turno simultáneamente durante picos estacionales.
* **Alta Disponibilidad:** Configurado en clúster con réplica en otra Zona de Disponibilidad (Multi-AZ) y failover automático para garantizar continuidad operativa.

---

## 3. Amazon S3

### ¿Qué es y qué función cumple?

Es el repositorio de almacenamiento de objetos escalable, duradero (99.999999999% de durabilidad) y seguro para todos los archivos no estructurados y binarios.

### ¿Por qué es necesario para el proyecto?

* **Almacenamiento de Archivos Médicos y Multimedia:** Guarda grabaciones de videoconsultas en vivo (autorizadas por el paciente), recetas digitales firmadas (PDFs generados por Lambda) y resultados de laboratorio/estudios médicos.
* **Desacoplamiento de Carga de la Base de Datos:** Mantiene la base de datos relacional (Aurora) ligera y eficiente al no almacenar datos binarios pesados (BLOBs) dentro de las tablas.
* **Gestión del Ciclo de Vida de los Datos (Data Lifecycle Management - DLM):** Permite configurar reglas de ciclo de vida automáticas para mover grabaciones y estudios antiguos a clases de almacenamiento frío (**S3 Glacier Flexible / Deep Archive**), reduciendo costos drásticamente mientras se cumple con los plazos legales de retención clínica.
* **Control de Acceso y URLs Prefirmadas:** Permite generar enlaces temporales de acceso seguro para que únicamente el médico y el paciente autorizados puedan visualizar los archivos médicos por un tiempo determinado.

---

## 4. Amazon Backup

### ¿Qué es y qué función cumple?

Es un servicio totalmente administrado y basado en políticas que centraliza, automatiza y orquesta las copias de seguridad de múltiples servicios de AWS (Amazon Aurora, Amazon S3, volúmenes EBS y DynamoDB si existieran).

### ¿Por qué se implementa en lugar de los backups nativos independientes de Aurora?

* **Punto Único de Control y Gobernanza:** En lugar de configurar, monitorear y mantener políticas de backup aisladas en cada motor (un esquema para Aurora, otro para S3, etc.), AWS Backup unifica toda la estrategia en una única consola y conjunto de políticas corporativas.
* **Políticas Automatizadas entre Cuentas (Cross-Account & Cross-Region Backup):** Permite programar copias de seguridad automáticas hacia una cuenta de auditoría/seguridad aislada o hacia una región secundaria, protegiendo a la organización contra borrados accidentales, corrupción de datos o ataques de ransomware.
* **Cumplimiento Regulatorio Simplificado (HIPAA / Leyes Locales de Salud):** Facilita la aplicación de directivas inmutables (**AWS Backup Vault Lock**), impidiendo que ningún usuario (incluso con privilegios de root/administrador) modifique o elimine copias de historias clínicas antes de cumplir el plazo legal obligatorio.
* **Reducción de Sobrecarga Operativa:** Para un equipo de 12 personas, AWS Backup automatiza la retención, la transición a almacenamiento de archivo y la auditoría de conformidad con reportes listos para inspecciones legales.
