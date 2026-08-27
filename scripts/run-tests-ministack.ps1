# Script para ejecutar tests de Terraform con MiniStack
param(
    [string]$Module = "all"
)

$ErrorActionPreference = "Stop"
$projectRoot = "D:\Archivos de programa D\GDrive\vitalmed-telehealth-platform"
$terraformPath = "$env:USERPROFILE\bin"

# Agregar Terraform al PATH
$env:PATH = "$terraformPath;" + $env:PATH

Write-Host "=== Ejecutando tests de Terraform con MiniStack ===" -ForegroundColor Cyan

# Verificar que MiniStack está ejecutándose
try {
    $response = Invoke-WebRequest -Uri "http://localhost:4566/_ministack/health" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -ne 200) {
        throw "MiniStack no está respondiendo correctamente"
    }
    Write-Host "MiniStack está ejecutándose" -ForegroundColor Green
} catch {
    Write-Host "Error: MiniStack no está ejecutándose" -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts\start-ministack.ps1" -ForegroundColor Yellow
    exit 1
}

# Verificar que tflocal está disponible
$tflocalPath = "C:\Users\alanz\AppData\Roaming\Python\Python312\Scripts"
$env:PATH = "$tflocalPath;" + $env:PATH

try {
    $tfVersion = & tflocal --version 2>&1 | Select-Object -First 1
    Write-Host "tflocal: $tfVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: tflocal no está disponible" -ForegroundColor Red
    Write-Host "Instala con: pip install terraform-local" -ForegroundColor Yellow
    exit 1
}

# Lista de módulos
$modules = @(
    "network",
    "compute",
    "data",
    "edge",
    "async"
)

if ($Module -ne "all") {
    $modules = @($Module)
}

$failedTests = @()
$passedTests = @()

foreach ($mod in $modules) {
    $testDir = "$projectRoot\terraform\modules\$mod\tests"
    $moduleDir = "$projectRoot\terraform\modules\$mod"
    
    if (-not (Test-Path $testDir)) {
        Write-Host "`nSaltando $mod - directorio de tests no encontrado" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`n=== Testeando módulo: $mod ===" -ForegroundColor Cyan
    
    # Copiar configuración de MiniStack al directorio del módulo
    $providerFile = "$moduleDir\localstack_providers_override.tf"
    Copy-Item "$projectRoot\terraform\tests\ministack-provider.tf" $providerFile -Force
    
    try {
        # Ejecutar tflocal init
        Write-Host "Inicializando..." -ForegroundColor Gray
        Push-Location $moduleDir
        & tflocal init -backend=false 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "tflocal init falló"
        }
        
        # Ejecutar tflocal test
        Write-Host "Ejecutando tests..." -ForegroundColor Gray
        & tflocal test "$testDir" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $passedTests += $mod
            Write-Host "✓ Tests de $mod pasaron" -ForegroundColor Green
        } else {
            $failedTests += $mod
            Write-Host "✗ Tests de $mod fallaron" -ForegroundColor Red
        }
    } catch {
        $failedTests += $mod
        Write-Host "✗ Error en $mod : $_" -ForegroundColor Red
    } finally {
        Pop-Location
        # Limpiar archivo de override
        if (Test-Path $providerFile) {
            Remove-Item $providerFile -Force
        }
    }
}

# Resumen
Write-Host "`n=== Resumen ===" -ForegroundColor Cyan
Write-Host "Tests pasados: $($passedTests.Count)" -ForegroundColor Green
Write-Host "Tests fallidos: $($failedTests.Count)" -ForegroundColor Red

if ($failedTests.Count -gt 0) {
    Write-Host "`nMódulos con errores:" -ForegroundColor Red
    foreach ($mod in $failedTests) {
        Write-Host "  - $mod" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`n¡Todos los tests pasaron!" -ForegroundColor Green
    exit 0
}
