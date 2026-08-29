#!/usr/bin/env bash
# ==============================================================================
# run-tests-localstack.sh — Ejecuta tests de Terraform con LocalStack
# Uso: ./scripts/run-tests-localstack.sh [network|compute|data|edge|async]
# Requisitos: terraform o tflocal, LocalStack en http://localhost:4566
# Nota: Preferir run-tests-ministack.sh (MiniStack no requiere licencia)
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODULE_FILTER="${1:-all}"

# Permitir override del comando terraform (tflocal si está instalado)
TF_CMD="${TF_CMD:-terraform}"
if command -v tflocal >/dev/null 2>&1 && [ "$TF_CMD" = "terraform" ]; then
  TF_CMD="tflocal"
fi

echo -e "${CYAN}=== Ejecutando tests de Terraform con LocalStack ($TF_CMD) ===${NC}"

if ! curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
  echo -e "${RED}Error: LocalStack no está ejecutándose${NC}"
  echo -e "${YELLOW}Ejecuta primero: ./scripts/start-localstack.sh${NC}"
  exit 1
fi
echo -e "${GREEN}LocalStack está ejecutándose${NC}"

if ! command -v "$TF_CMD" >/dev/null 2>&1; then
  echo -e "${RED}$TF_CMD no encontrado en PATH${NC}"
  exit 1
fi

ALL_MODULES=("network" "compute" "data" "edge" "async")
if [ "$MODULE_FILTER" = "all" ]; then
  MODULES=("${ALL_MODULES[@]}")
else
  MODULES=("$MODULE_FILTER")
fi

FAILED=()
PASSED=()

for mod in "${MODULES[@]}"; do
  TEST_DIR="$PROJECT_ROOT/terraform/modules/$mod/tests"
  MODULE_DIR="$PROJECT_ROOT/terraform/modules/$mod"

  if [ ! -d "$TEST_DIR" ]; then
    echo -e "\n${YELLOW}Saltando $mod - directorio de tests no encontrado${NC}"
    continue
  fi

  echo -e "\n${CYAN}=== Testeando módulo: $mod ===${NC}"

  PROVIDER_SRC="$PROJECT_ROOT/terraform/tests/localstack-provider.tf"
  PROVIDER_FILE="$MODULE_DIR/localstack_providers_override.tf"
  CREATED_OVERRIDE=false
  if [ -f "$PROVIDER_SRC" ] && [ ! -f "$PROVIDER_FILE" ]; then
    cp "$PROVIDER_SRC" "$PROVIDER_FILE"
    CREATED_OVERRIDE=true
  fi

  set +e
  (
    cd "$MODULE_DIR"
    echo -e "${GRAY}Inicializando...${NC}"
    $TF_CMD init -backend=false >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo -e "${RED}$TF_CMD init falló${NC}"
      exit 1
    fi
    echo -e "${GRAY}Ejecutando tests...${NC}"
    $TF_CMD test 2>&1
  )
  RC=$?
  set -e

  if [ "$CREATED_OVERRIDE" = true ]; then
    rm -f "$PROVIDER_FILE"
  fi

  if [ $RC -eq 0 ]; then
    PASSED+=("$mod")
    echo -e "${GREEN}✓ Tests de $mod pasaron${NC}"
  else
    FAILED+=("$mod")
    echo -e "${RED}✗ Tests de $mod fallaron${NC}"
  fi
done

echo -e "\n${CYAN}=== Resumen ===${NC}"
echo -e "${GREEN}Tests pasados: ${#PASSED[@]}${NC}"
echo -e "${RED}Tests fallidos: ${#FAILED[@]}${NC}"

if [ ${#FAILED[@]} -gt 0 ]; then
  echo -e "\n${RED}Módulos con errores:${NC}"
  for m in "${FAILED[@]}"; do echo -e "  ${RED}- $m${NC}"; done
  exit 1
else
  echo -e "\n${GREEN}¡Todos los tests pasaron!${NC}"
  exit 0
fi
