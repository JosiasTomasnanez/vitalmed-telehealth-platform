# Script para validar Terraform sin credenciales AWS
$ErrorActionPreference = "Stop"
$projectRoot = "D:\Archivos de programa D\GDrive\vitalmed-telehealth-platform"
$terraformPath = "$env:USERPROFILE\bin"
$env:PATH = "$terraformPath;" + $env:PATH

Write-Host "=== Validacion de Terraform ===" -ForegroundColor Cyan

# Verificar Terraform
$tfVersion = terraform version 2>&1 | Select-Object -First 1
Write-Host "Terraform: $tfVersion" -ForegroundColor Green

# Formateo
Write-Host "`n1. Verificando formateo..." -ForegroundColor Yellow
$fmtCheck = terraform fmt -check -recursive 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   Formateo correcto" -ForegroundColor Green
} else {
    Write-Host "   Archivos con formato incorrecto, aplicando fmt..." -ForegroundColor Yellow
    terraform fmt -recursive
}

# Validacion de modulos
Write-Host "`n2. Validando modulos..." -ForegroundColor Yellow
$modules = @("network", "compute", "data", "edge", "async")
foreach ($mod in $modules) {
    $modPath = "$projectRoot\terraform\modules\$mod"
    Write-Host "   Modulo: $mod" -ForegroundColor Gray
    Push-Location $modPath
    terraform init -backend=false 2>&1 | Out-Null
    $result = terraform validate 2>&1
    Pop-Location
    if ($result -match "is valid") {
        Write-Host "   $mod valido" -ForegroundColor Green
    } else {
        Write-Host "   $mod invalido" -ForegroundColor Red
    }
}

# Validacion de environments
Write-Host "`n3. Validando environments..." -ForegroundColor Yellow
$environments = @("ar/preprod", "ar/prod", "cl/preprod", "cl/prod", "co/preprod", "co/prod", "mx/preprod", "mx/prod")
foreach ($envName in $environments) {
    $envPath = "$projectRoot\terraform\environments\$envName"
    Write-Host "   Environment: $envName" -ForegroundColor Gray
    if (-not (Test-Path $envPath)) {
        Write-Host "   Directorio no encontrado" -ForegroundColor Yellow
        continue
    }
    Push-Location $envPath
    terraform init -backend=false 2>&1 | Out-Null
    $result = terraform validate 2>&1
    Pop-Location
    if ($result -match "is valid") {
        Write-Host "   $envName valido" -ForegroundColor Green
    } else {
        Write-Host "   $envName invalido" -ForegroundColor Red
    }
}

Write-Host "`n=== Validacion completada ===" -ForegroundColor Cyan
