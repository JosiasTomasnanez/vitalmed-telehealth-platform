# Tests de Terraform con MiniStack

## Resumen

Los tests de Terraform se ejecutan utilizando **MiniStack** como emulador local de AWS. MiniStack es una alternativa gratuita y open-source a LocalStack que emula más de 60 servicios de AWS en un solo puerto (4566).

## Requisitos previos

1. **Docker Desktop** - debe estar instalado y ejecutándose
2. **Terraform** - versión 1.10.0 o superior
3. **Python 3.x** - para tflocal (opcional)

## Inicio rápido

### 1. Iniciar MiniStack

```powershell
./scripts/start-ministack.sh
```

O manualmente:

```bash
docker run -d --name ministack -p 4566:4566 ministackorg/ministack
```

### 2. Verificar que MiniStack está ejecutándose

```bash
curl http://localhost:4566/_ministack/health
```

### 3. Ejecutar tests

```powershell
# Ejecutar todos los tests
./scripts/run-tests-ministack.sh

# Ejecutar tests de un módulo específico
./scripts/run-tests-ministack.sh -Module network
./scripts/run-tests-ministack.sh -Module compute
./scripts/run-tests-ministack.sh -Module data
./scripts/run-tests-ministack.sh -Module edge
./scripts/run-tests-ministack.sh -Module async
```

O manualmente:

```bash
cd terraform/modules/network
terraform init -backend=false
terraform test ./tests/network.tftest.hcl
```

## Resultados de los tests

| Módulo | Tests | Estado |
|--------|-------|--------|
| network | 3 | ✅ Todos pasaron |
| compute | 8 | ✅ Todos pasaron |
| data | 9 | ✅ Todos pasaron |
| edge | 7 | ✅ Todos pasaron |
| async | 6 | ✅ Todos pasaron |
| **Total** | **33** | ✅ |

## Cómo funcionan los tests

Los tests de Terraform utilizan el comando `terraform test` que:

1. Inicializa el módulo con `terraform init -backend=false`
2. Ejecuta los bloques `run` definidos en los archivos `.tftest.hcl`
3. Cada bloque `run` puede usar `command = plan` o `command = apply`
4. Los asserts verifican que las condiciones se cumplan

### Provider para MiniStack

Los módulos incluyen un archivo `provider.tf` que configura el provider de AWS para apuntar a MiniStack:

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3             = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    # ... otros servicios
  }
}
```

## Solución de problemas

### Error: "No valid credential sources found"

Asegúrese de que el archivo `provider.tf` existe en el módulo y está configurado correctamente.

### Error: "couldn't find resource" para Route53

Los tests de Route53 requieren que el hosted zone exista. El script `start-ministack.sh` crea automáticamente el hosted zone necesario.

### Error: "Cannot index a set value"

Los bloques `ingress` y `setting` en AWS son conjuntos (sets), no listas. Use expresiones `for` en lugar de índices:

```hcl
# Incorrecto
condition = aws_security_group.example.ingress[0].from_port == 443

# Correcto
condition = contains([for i in aws_security_group.example.ingress : i.from_port], 443)
```

### Error: "invalid account ID" en ARNs

Los ARNs de prueba deben tener un account ID de 12 dígitos:

```hcl
# Incorrecto
certificate_arn = "arn:aws:acm:us-east-1:123456789:certificate/test"

# Correcto
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/test"
```

### Error: "invalid value for name (cannot begin with sg-)"

Los nombres de security groups no pueden comenzar con "sg-":

```hcl
# Incorrecto
name = "sg-alb-${local.nombre}"

# Correcto
name = "alb-${local.nombre}"
```

## Endpoints de MiniStack

| Servicio | URL |
|----------|-----|
| Health check | http://localhost:4566/_ministack/health |
| Reset state | POST http://localhost:4566/_ministack/reset |
| S3 | http://localhost:4566 |
| SQS | http://localhost:4566 |
| Lambda | http://localhost:4566 |
| EC2 | http://localhost:4566 |
| IAM | http://localhost:4566 |
| RDS | http://localhost:4566 |
| CloudFront | http://localhost:4566 |
| WAFv2 | http://localhost:4566 |
| Route53 | http://localhost:4566 |

## Recursos útiles

- [MiniStack GitHub](https://github.com/ministackorg/ministack)
- [MiniStack Documentation](https://ministack.org)
- [Terraform Test Documentation](https://developer.hashicorp.com/terraform/language/tests)
