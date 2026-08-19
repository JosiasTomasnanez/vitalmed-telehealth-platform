# Grupo 9: Plataforma de Telemedicina e Historia Clínica Electrónica 

## Pilar: Excelencia Operativa

## Contexto del cliente

"VitalMed Telesalud" es una plataforma de telemedicina que opera en Argentina, Chile, Colombia y México, conectando a más de 180,000 pacientes con una red de 4,500 profesionales de la salud. Ofrece videoconsultas, recetas digitales, resultados de laboratorio y un módulo de historia clínica electrónica (HCE) compartido entre especialistas. El equipo de tecnología es reducido (alrededor de 12 personas) para el nivel de operación en cuatro países.

## Especificaciones técnicas y requerimientos

**Infraestructura de la Web**

-   Frontend: aplicación web y móvil para pacientes (turnos, videoconsulta, resultados) y portal para profesionales de la salud (agenda, historia clínica, indicaciones). Requiere baja latencia durante las videoconsultas en vivo.

-   Backend: arquitectura de microservicios para turnos, facturación a aseguradoras, gestión de historia clínica y videollamadas. El equipo no quiere administrar servidores manualmente y necesita minimizar la carga operativa.

**Distribución de usuarios**

-   Concentración de usuarios en las capitales y grandes áreas metropolitanas de los cuatro países, con picos marcados en temporada de enfermedades respiratorias (otoño/invierno) y durante campañas de vacunación, donde las consultas pueden multiplicarse por 4.

**Datos y análisis**

-   Los registros médicos, resultados de laboratorio y grabaciones de consultas (cuando el paciente lo autoriza) son datos sensibles de salud, sujetos a normativas locales de protección de datos equivalentes a HIPAA. Se requiere trazabilidad completa de accesos (quién vio qué historia clínica y cuándo) y separación de datos entre países por requerimientos regulatorios locales.

**Escalabilidad y disponibilidad**

-   La plataforma no puede tener caídas durante el horario de atención (7 a 23 h en cada país) y debe poder escalar rápidamente ante picos estacionales sin sobre-provisionar el resto del año.

## Pilar Fundamental del Well-Architected Framework: Excelencia Operativa

Referencia: [AWS Well-Architected Framework](https://docs.aws.amazon.com/pdfs/wellarchitected/latest/framework/wellarchitected-framework.pdf)

> El CTO de la empresa hizo mucho énfasis en el pilar de Excelencia Operativa (Operational Excellence), mencionando que con un equipo de tecnología reducido, la única forma de sostener el crecimiento a cuatro países sin aumentar drásticamente la plantilla es tener visibilidad total del sistema, automatizar los despliegues y poder reaccionar ante un incidente antes de que impacte a un paciente en medio de una consulta médica.

## Consigna de trabajo

### Parte 1 – Diseño de Infraestructura en AWS

**1. Diseño de la solución – Definición de Servicios** En grupo, definan los servicios de AWS necesarios, justificando cada elección en relación con los requisitos del cliente, en particular la necesidad de operar con un equipo reducido en cuatro países con separación de datos por regulación local. Cuando falten datos para tomar una decisión, indiquen explícitamente los supuestos que asumen.

**2. Diagrama de Arquitectura** Desarrollen un diagrama de arquitectura detallado que muestre la interacción entre los servicios elegidos, incluyendo cómo se aísla o replica la información por país.

**3. Análisis de Costos** Realicen una estimación de costos mensuales usando la [Calculadora de Precios de AWS](https://calculator.aws), considerando carga habitual y el pico estacional (hasta 4x consultas).

**4. Planificación de Despliegue** Elaboren un plan de configuración de infraestructura, migración y pruebas, incluyendo cómo se incorporaría un quinto país sin rediseñar la solución.

**5. Foco de Evaluación — Pilar Excelencia Operativa** Al definir su arquitectura (Parte 1), resuelvan explícitamente estos aspectos:

-   Cómo obtienen visibilidad de punta a punta sobre las videoconsultas y los microservicios críticos, con alertas proactivas antes de que un paciente pierda una consulta.

-   Cómo automatizan despliegues y cambios, dado que el equipo de 12 personas no puede sostener procesos manuales en cuatro países.

-   Cómo responderían operativamente ante un incidente en horario de atención (7 a 23 h en cada país).

-   Qué tareas repetitivas de operación automatizan para reducir la carga manual del equipo.

-   Cómo diseñan un proceso de mejora continua que permita escalar sin escalar linealmente el equipo.

Para cada punto anterior, indiquen también cómo validarían esa decisión.

### Parte 2 – Infraestructura como Código con Terraform

**Validación de Terraform**

> No es obligatorio ejecutar `terraform apply` ni desplegar la solución completa en una cuenta real de AWS. Podrán utilizar AWS Academy para realizar validaciones parciales, teniendo en cuenta que sus permisos, servicios y regiones disponibles pueden ser limitados.
>
> El código deberá poder evaluarse sin crear infraestructura real. Como mínimo, deberán ejecutar:
>
> ```bash
> terraform fmt -check
> terraform init -backend=false
> terraform validate
> terraform test
> ```
>
> La ejecución de `terraform plan` contra una cuenta real será opcional y dependerá de los permisos disponibles. La ejecución de `terraform apply` no forma parte de los requisitos obligatorios.
>
> Las pruebas deberán estar incluidas en el repositorio y ser reproducibles. Las capturas o logs podrán presentarse como evidencia complementaria.

**Trabajo Grupal** Establezcan un flujo de trabajo colaborativo: uso de un repositorio, peer reviews y estrategia de merge.

### Parte 3 – Runbook de Despliegue

Elaboren un runbook breve y preciso que incluya:

-   Prerrequisitos y permisos necesarios.

-   Configuración de variables.

-   Orden de despliegue.

-   Validaciones previas y posteriores.

-   Estrategia de rollback.

-   Pruebas relacionadas con el pilar de Excelencia Operativa.

-   Limitaciones o validaciones que requerirían una cuenta real de AWS.

## Entregables

1.  Documento técnico con decisiones, justificaciones, supuestos, costos y aplicación del pilar.

2.  Diagrama de arquitectura.

3.  Repositorio con el código y las pruebas de Terraform.

4.  Runbook de despliegue.

5.  Presentación grupal y defensa técnica de la solución.

## Criterios de evaluación

| Criterio | Foco de evaluación |
|---|---|
| Comprensión del caso | Identificación de requisitos, restricciones y supuestos |
| Servicios AWS | Justificación de los servicios seleccionados |
| Arquitectura | Coherencia, claridad e integración de la solución |
| Pilar asignado | Aplicación efectiva de la Excelencia Operativa en el diseño y las decisiones (operación en 4 países). |
| Costos | Calidad de los supuestos y comparación entre escenarios |
| Terraform | Modularidad, legibilidad, mantenibilidad y correspondencia con la arquitectura |
| Pruebas | Calidad de las assertions, uso adecuado de mocks y reproducibilidad |
| Runbook | Claridad, viabilidad, validaciones y rollback |
| Trabajo grupal | Versionado, revisiones y participación |
| Defensa técnica | Capacidad para justificar y adaptar las decisiones |


