# Script para iniciar MiniStack (alternativa gratuita a LocalStack)
Write-Host "=== Iniciando MiniStack ===" -ForegroundColor Cyan

# Verificar que Docker está ejecutándose
$dockerRunning = docker info 2>&1 | Select-String -Pattern "Server Version"
if (-not $dockerRunning) {
    Write-Host "Docker no está ejecutándose. Por favor, inicia Docker Desktop." -ForegroundColor Red
    exit 1
}

# Verificar si ya está corriendo
$running = docker ps --filter "name=ministack" --format "{{.Names}}"
if ($running) {
    Write-Host "MiniStack ya está ejecutándose" -ForegroundColor Green
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:4566/_ministack/health" -UseBasicParsing -ErrorAction Stop
        Write-Host "Health check OK" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "Reiniciando MiniStack..." -ForegroundColor Yellow
        docker stop ministack 2>$null
        docker rm ministack 2>$null
    }
}

# Iniciar MiniStack
Write-Host "Iniciando contenedor MiniStack..." -ForegroundColor Cyan
docker run -d `
    --name ministack `
    -p 4566:4566 `
    ministackorg/ministack

# Esperar a que MiniStack esté listo
Write-Host "Esperando a que MiniStack esté listo..." -ForegroundColor Yellow
$maxAttempts = 15
$attempt = 0
$ready = $false

while (-not $ready -and $attempt -lt $maxAttempts) {
    $attempt++
    Start-Sleep -Seconds 2
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:4566/_ministack/health" -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $ready = $true
            Write-Host "MiniStack está listo!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Intento $attempt/$maxAttempts - Esperando..." -ForegroundColor Gray
    }
}

if (-not $ready) {
    Write-Host "MiniStack no se inició correctamente. Revisa los logs con: docker logs ministack" -ForegroundColor Red
    exit 1
}

# Verificar servicios clave
Write-Host "`nServicios disponibles:" -ForegroundColor Cyan
$health = $response.Content | ConvertFrom-Json
$services = @("ec2", "s3", "sqs", "lambda", "iam", "cloudwatch", "logs", "kms", "ssm")
foreach ($svc in $services) {
    if ($health.services.$svc -eq "available") {
        Write-Host "  ✓ $svc" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $svc (no disponible)" -ForegroundColor Red
    }
}

Write-Host "`nMiniStack está ejecutándose en http://localhost:4566" -ForegroundColor Green
Write-Host "Para detener: docker stop ministack" -ForegroundColor Gray
