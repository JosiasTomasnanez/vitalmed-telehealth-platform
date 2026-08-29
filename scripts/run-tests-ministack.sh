#!/usr/bin/env bash

# Script para ejecutar tests de Terraform con MiniStack
# Uso: ./test-ministack.sh [nombre_modulo|all]

MODULE="${1:-all}"

# Colores para la consola
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m' # Sin color

# Detección dinámica del directorio raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

echo -e "${CYAN}=== Ejecutando tests de Terraform con MiniStack ===${NC}"

# Verificar que MiniStack está ejecutándose
if curl -s -f "http://localhost:4566/_ministack/health" > /dev/null 2>&1; then
    echo -e "${GREEN}MiniStack está ejecutándose${NC}"
else
    echo -e "${RED}Error: MiniStack no está ejecutándose${NC}"
    echo -e "${YELLOW}Ejecuta primero: ./scripts/start-ministack.sh${NC}"
    exit 1
fi

# Verificar que tflocal está disponible
if command -v tflocal &> /dev/null; then
    TF_VERSION=$(tflocal --version 2>&1 | head -n 1)
    echo -e "${GREEN}tflocal: ${TF_VERSION}${NC}"
else
    echo -e "${RED}Error: tflocal no está disponible${NC}"
    echo -e "${YELLOW}Instala con: pip install terraform-local${NC}"
    exit 1
fi

# Lista de módulos
if [ "$MODULE" != "all" ]; then
    MODULES=("$MODULE")
else
    MODULES=("network" "compute" "data" "edge" "async")
fi

FAILED_TESTS=()
PASSED_TESTS=()
ORIGINAL_DIR="$(pwd)"

for mod in "${MODULES[@]}"; do
    TEST_DIR="${PROJECT_ROOT}/terraform/modules/${mod}/tests"
    MODULE_DIR="${PROJECT_ROOT}/terraform/modules/${mod}"
    PROVIDER_FILE="${MODULE_DIR}/localstack_providers_override.tf"

    if [ ! -d "$TEST_DIR" ]; then
        echo -e "\n${YELLOW}Saltando ${mod} - directorio de tests no encontrado${NC}"
        continue
    fi

    echo -e "\n${CYAN}=== Testeando módulo: ${mod} ===${NC}"

    # Copiar configuración de MiniStack al directorio del módulo
    cp "${PROJECT_ROOT}/terraform/tests/ministack-provider.tf" "$PROVIDER_FILE"

    cd "$MODULE_DIR" || continue

    # Inicializar tflocal
    echo -e "${GRAY}Inicializando...${NC}"
    if tflocal init -backend=false > /dev/null 2>&1; then
        echo -e "${GRAY}Ejecutando tests...${NC}"
        
        # Ejecutar tflocal test
        if tflocal test "$TEST_DIR"; then
            PASSED_TESTS+=("$mod")
            echo -e "${GREEN}✓ Tests de ${mod} pasaron${NC}"
        else
            FAILED_TESTS+=("$mod")
            echo -e "${RED}✗ Tests de ${mod} fallaron${NC}"
        fi
    else
        FAILED_TESTS+=("$mod")
        echo -e "${RED}✗ Error en ${mod} : tflocal init falló${NC}"
    fi

    # Limpiar archivo de override
    if [ -f "$PROVIDER_FILE" ]; then
        rm -f "$PROVIDER_FILE"
    fi

    cd "$ORIGINAL_DIR" || exit 1
done

# Resumen
echo -e "\n${CYAN}=== Resumen ===${NC}"
echo -e "${GREEN}Tests pasados: ${#PASSED_TESTS[@]}${NC}"
echo -e "${RED}Tests fallidos: ${#FAILED_TESTS[@]}${NC}"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo -e "\n${RED}Módulos con errores:${NC}"
    for mod in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  - ${mod}${NC}"
    done
    exit 1
else
    echo -e "\n${GREEN}¡Todos los tests pasaron!${NC}"
    exit 0
fi
