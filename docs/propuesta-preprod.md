# Propuesta: Estrategia de Cuentas Preproducción

**Autor:** Gabriel (Grupo 9 - Excelencia Operativa)  
**Fecha:** 26 de agosto de 2026  
**Estado:** Propuesta para revisión del equipo

---

## Resumen Ejecutivo

El equipo debe decidir entre mantener **4 cuentas preprod** (una por país) o simplificar a **1 cuenta preprod** compartida. Esta propuesta analiza ambas opciones con impacto en costo, complejidad y operabilidad.

---

## Contexto Actual

### Estructura de cuentas en Terraform

```
Organización AWS
├── Management Account (org/)
├── Shared Account (state-backend)
└── Workload Accounts (8 total)
    ├── ar-prod
    ├── ar-preprod    ← ¿Mantenemos o eliminamos?
    ├── cl-prod
    ├── cl-preprod    ← ¿Mantenemos o eliminamos?
    ├── co-prod
    ├── co-preprod    ← ¿Mantenemos o eliminamos?
    ├── mx-prod
    └── mx-preprod    ← ¿Mantenemos o eliminamos?
```

### Infraestructura actual por cuenta

Cada cuenta (prod y preprod) incluye:
- VPC propia con 3 subnets (pública, privada, datos)
- NAT Gateway (1 por AZ en prod, 1 total en preprod)
- ALB + ECS Fargate
- Aurora Serverless v2 (con 2 AZs en prod, 1 en preprod)
- S3 + KMS + Secrets Manager
- SQS + Lambda
- CloudFront + WAF + Route53

---

## Opción A: Mantener 4 Preprods (Actual)

### Estructura

```
├── ar-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
├── ar-preprod   → VPC, ALB, ECS, Aurora (1 AZ), NAT x1
├── cl-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
├── cl-preprod   → VPC, ALB, ECS, Aurora (1 AZ), NAT x1
├── co-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
├── co-preprod   → VPC, ALB, ECS, Aurora (1 AZ), NAT x1
├── mx-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
└── mx-preprod   → VPC, ALB, ECS, Aurora (1 AZ), NAT x1
```

### Ventajas

| Ventaja | Descripción |
|---------|-------------|
| **Aislamiento total** | Cada país tiene su preprod independiente |
| **Testing realista** | Preprod refleja exactamente la config de prod por país |
| **Sin conflictos** | No hay riesgo de colisiones de recursos o CIDRs |
| **Despliegue paralelo** | Se puede testear un país sin afectar a otros |
| **Cumplimiento** | Cada país mantiene sus requisitos de residencia de datos |

### Desventajas

| Desventaja | Impacto |
|------------|---------|
| **Costo** | ~$400-600 USD/mes extra (4 VPCs, NATs, Aurora) |
| **Complejidad** | 8 cuentas para gestionar en vez de 5 |
| **Mantenimiento** | 8 sets de configuración Terraform |
| **Operaciones** | Más cuentas = más superficie de error |

### Costo estimado mensual (preprod)

| Servicio | Costo por país | Total 4 países |
|----------|----------------|----------------|
| NAT Gateway | ~$32 | ~$128 |
| Aurora Serverless (0.5 ACU) | ~$45 | ~$180 |
| ECS Fargate (2 tareas) | ~$30 | ~$120 |
| ALB | ~$20 | ~$80 |
| S3 + KMS + Secrets | ~$10 | ~$40 |
| **Total preprod** | ~$137 | **~$548/mes** |

---

## Opción B: 1 sola Preprod (Propuesta)

### Estructura

```
├── ar-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
├── cl-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
├── co-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
├── mx-prod      → VPC, ALB, ECS, Aurora (2 AZs), NAT x AZ
└── preprod      → VPC compartida, ALB, ECS (configurable por país)
```

### Diseño de la cuenta preprod compartida

```hcl
# terraform/environments/preprod/main.tf

# Variables para configuración por país
variable "config_paises" {
  default = {
    ar = {
      cidr             = "10.99.0.0/16"
      vpc_cidr         = "10.99.0.0/16"
      public_subnets   = ["10.99.0.0/24", "10.99.1.0/24"]
      private_subnets  = ["10.99.10.0/24", "10.99.11.0/24"]
      data_subnets     = ["10.99.20.0/24", "10.99.21.0/24"]
    }
    cl = {
      cidr             = "10.98.0.0/16"
      vpc_cidr         = "10.98.0.0/16"
      public_subnets   = ["10.98.0.0/24", "10.98.1.0/24"]
      private_subnets  = ["10.98.10.0/24", "10.98.11.0/24"]
      data_subnets     = ["10.98.20.0/24", "10.98.21.0/24"]
    }
    co = {
      cidr             = "10.97.0.0/16"
      vpc_cidr         = "10.97.0.0/16"
      public_subnets   = ["10.97.0.0/24", "10.97.1.0/24"]
      private_subnets  = ["10.97.10.0/24", "10.97.11.0/24"]
      data_subnets     = ["10.97.20.0/24", "10.97.21.0/24"]
    }
    mx = {
      cidr             = "10.96.0.0/16"
      vpc_cidr         = "10.96.0.0/16"
      public_subnets   = ["10.96.0.0/24", "10.96.1.0/24"]
      private_subnets  = ["10.96.10.0/24", "10.96.11.0/24"]
      data_subnets     = ["10.96.20.0/24", "10.96.21.0/24"]
    }
  }
}

# VPC compartida con subnets por país
module "network" {
  source = "../../modules/network"

  for_each = var.config_paises

  pais                 = each.key
  entorno              = "preprod"
  vpc_cidr             = each.value.cidr
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = each.value.public_subnets
  private_subnet_cidrs = each.value.private_subnets
  data_subnet_cidrs    = each.value.data_subnets
  single_nat_gateway   = true  # Un solo NAT para preprod
}
```

### Ventajas

| Ventaja | Descripción |
|---------|-------------|
| **Ahorro significativo** | ~$350 USD/mes menos (1 VPC vs 4) |
| **Menos complejidad** | 5 cuentas en vez de 8 |
| **Mantenimiento simpler** | 1 config de preprod vs 4 |
| **Operaciones** | Menos cuentas = menos superficie de error |
| **Suficiente para testing** | Los cambios son iguales para todos los países |

### Desventajas

| Desventaja | Mitigación |
|------------|------------|
| **No refleja config por país** | Usar variables para simular diferencias |
| **Riesgo de conflictos** | CIDRs únicos por país en la misma VPC |
| **Despliegue acoplado** | Testing por país usando workspaces |
| **Posible loss of fidelity** | Aceptar que preprod no es idéntico a prod |

### Costo estimado mensual (preprod)

| Servicio | Costo | Ahorro vs Opción A |
|----------|-------|-------------------|
| NAT Gateway (1 total) | ~$32 | -$96 |
| Aurora Serverless (0.5 ACU, 1 AZ) | ~$45 | -$135 |
| ECS Fargate (2 tareas) | ~$30 | -$90 |
| ALB | ~$20 | -$60 |
| S3 + KMS + Secrets | ~$10 | -$30 |
| **Total preprod** | **~$137** | **~-$411/mes** |

---

## Comparación Directa

| Criterio | Opción A (4 preprods) | Opción B (1 preprod) | Ganador |
|----------|----------------------|---------------------|---------|
| **Costo mensual** | ~$548 | ~$137 | 🏆 Opción B |
| **Complejidad Terraform** | 8 environments | 5 environments | 🏆 Opción B |
| **Fidelidad a prod** | Alta (1:1 por país) | Media (simula diferencias) | 🏆 Opción A |
| **Aislamiento** | Total | Parcial (por CIDR) | 🏆 Opción A |
| **Facilidad de uso** | Media | Alta | 🏆 Opción B |
| **Para equipo de 12** | Excesivo | Adecuado | 🏆 Opción B |

---

## Recomendación

### Para el contexto de este proyecto (Diplomatura DevOps, 12 personas):

**Recomendamos la Opción B: 1 sola cuenta preprod compartida.**

### Justificación

1. **Contexto educativo**: Es un proyecto de diplomatura, no producción real
2. **Equipo de 12**: La complejidad de 8 cuentas no está justificada
3. **Ahorro**: ~$4,900 USD/año en costos de AWS
4. **Suficiente**: Los cambios son iguales para todos los países
5. **Mantenimiento**: Simplifica el trabajo del equipo

### Cuándo cambiaría la recomendación

Si el proyecto fuera de **producción real** con:
- Equipo más grande (>20 personas)
- Diferentes equipos por país
- Requisitos regulatorios estrictos por país
- Necesidad de testing independiente por país

---

## Cambios Necesarios en Terraform (si eligen Opción B)

### 1. Eliminar carpetas de preprod por país

```
terraform/environments/
├── ar/prod/        ← se mantiene
├── cl/prod/        ← se mantiene
├── co/prod/        ← se mantiene
├── mx/prod/        ← se mantiene
└── preprod/        ← nueva carpeta compartida
```

### 2. Crear environment compartido de preprod

```hcl
# terraform/environments/preprod/main.tf
module "network_ar" {
  source = "../../modules/network"
  pais    = "ar"
  entorno = "preprod"
  # ... config por país
}

module "network_cl" {
  source = "../../modules/network"
  pais    = "cl"
  entorno = "preprod"
  # ... config por país
}
# ... etc para co y mx
```

### 3. Ajustar CIDRs para evitar conflictos

| País | CIDR Actual (prod) | CIDR Nuevo (preprod) |
|------|-------------------|---------------------|
| AR | 10.10.0.0/16 | 10.90.0.0/16 |
| CL | 10.20.0.0/16 | 10.91.0.0/16 |
| CO | 10.30.0.0/16 | 10.92.0.0/16 |
| MX | 10.40.0.0/16 | 10.93.0.0/16 |

### 4. Actualizar org/ para crear solo 5 cuentas

```hcl
# terraform/org/accounts.tf (cambiar de 8 a 5)
resource "aws_organizations_account" "workload" {
  for_each = {
    ar-prod  = { parent_id = aws_organizations_oun.ar.id }
    cl-prod  = { parent_id = aws_organizations_oun.cl.id }
    co-prod  = { parent_id = aws_organizations_oun.co.id }
    mx-prod  = { parent_id = aws_organizations_oun.mx.id }
    preprod  = { parent_id = aws_organizations_oun.shared.id }
  }
  # ...
}
```

---

## Próximos Pasos

1. **Decisión del equipo**: Votar entre Opción A o B
2. **Si eligen Opción B**: 
   - Crear `terraform/environments/preprod/`
   - Ajustar `terraform/org/` para 5 cuentas
   - Actualizar README con nueva estructura
   - Recalcular estimación de costos
3. **Si eligen Opción A**: 
   - Mantener estructura actual
   - Documentar justificación de 8 cuentas

---

## Documento de Soporte

- [Especificación Técnica AWS-DOC](https://josiastomasnanez.github.io/vitalmed-telehealth-platform/index.html)
- [README de Terraform](../README.md)
- [Estimación de Costos](../docs/cost-estimation.md)
