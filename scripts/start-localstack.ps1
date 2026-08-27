# Script para iniciar LocalStack
Write-Host "Iniciando LocalStack..." -ForegroundColor Green

# Verificar que Docker está ejecutándose
$dockerRunning = docker info 2>&1 | Select-String -Pattern "Server Version"
if (-not $dockerRunning) {
    Write-Host "Docker no está ejecutándose. Por favor, inicia Docker Desktop." -ForegroundColor Red
    exit 1
}

# Detener contenedor existente si existe
$existingContainer = docker ps -a --filter "name=localstack" --format "{{.Names}}"
if ($existingContainer) {
    Write-Host "Deteniendo contenedor existente..." -ForegroundColor Yellow
    docker stop localstack 2>$null
    docker rm localstack 2>$null
}

# Iniciar LocalStack
Write-Host "Iniciando contenedor LocalStack..." -ForegroundColor Cyan
docker run -d `
    --name localstack `
    -p 4566:4566 `
    -p 4510-4559:4510-4559 `
    -e SERVICES="s3,sqs,lambda,iam,cloudwatch,cloudtrail,logs,kms,ssm" `
    -e DEBUG=0 `
    -e DATA_DIR="/var/lib/localstack" `
    -e DOCKER_HOST=unix:///var/run/docker.sock `
    localstack/localstack

# Esperar a que LocalStack esté listo
Write-Host "Esperando a que LocalStack esté listo..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$ready = $false

while (-not $ready -and $attempt -lt $maxAttempts) {
    $attempt++
    Start-Sleep -Seconds 2
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:4566/_localstack/health" -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $ready = $true
            Write-Host "LocalStack está listo!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Intento $attempt/$maxAttempts - Esperando..." -ForegroundColor Gray
    }
}

if (-not $ready) {
    Write-Host "LocalStack no se inició correctamente. Revisa los logs con: docker logs localstack" -ForegroundColor Red
    exit 1
}

# Verificar servicios
Write-Host "`nServicios disponibles:" -ForegroundColor Cyan
docker exec localstack aws --endpoint-url=http://localhost:4566 s3 ls 2>&1 | Out-Null
Write-Host "- S3: OK" -ForegroundColor Green
docker exec localstack aws --endpoint-url=http://localhost:4566 sqs list-queues 2>&1 | Out-Null
Write-Host "- SQS: OK" -ForegroundColor Green
docker exec localstack aws --endpoint-url=http://localhost:4566 iam list-roles 2>&1 | Out-Null
Write-Host "- IAM: OK" -ForegroundColor Green

Write-Host "`nLocalStack está ejecutándose en http://localhost:4566" -ForegroundColor Green
Write-Host "Para detener: docker stop localstack" -ForegroundColor Gray
