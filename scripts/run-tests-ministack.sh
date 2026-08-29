#!/usr/bin/env bash
# ==============================================================================
# run-tests-ministack.sh — Ejecuta tests de Terraform con MiniStack
# Uso: ./scripts/run-tests-ministack.sh [network|compute|data|edge|async]
#      Sin argumento ejecuta todos los módulos.
# Requisitos: terraform, MiniStack en http://localhost:4566
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODULE_FILTER="${1:-all}"

echo -e "${CYAN}=== Ejecutando tests de Terraform con MiniStack ===${NC}"

# Verificar MiniStack
if ! curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
  echo -e "${RED}Error: MiniStack no está ejecutándose${NC}"
  echo -e "${YELLOW}Ejecuta primero: ./scripts/start-ministack.sh${NC}"
  exit 1
fi
echo -e "${GREEN}MiniStack está ejecutándose${NC}"

if ! command -v terraform >/dev/null 2>&1; then
  echo -e "${RED}terraform no encontrado en PATH${NC}"
  exit 1
fi

# Lista de módulos
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

  # Usar provider de MiniStack si existe uno dedicado; si no, el genérico
  PROVIDER_SRC=""
  if [ -f "$MODULE_DIR/ministack-provider.tf" ]; then
    echo -e "${GRAY}Usando provider existente en el módulo${NC}"
    PROVIDER_SRC=""
  elif [ -f "$PROJECT_ROOT/terraform/tests/ministack-provider.tf" ]; then
    PROVIDER_SRC="$PROJECT_ROOT/terraform/tests/ministack-provider.tf"
  fi

  PROVIDER_FILE=""
  if [ -n "$PROVIDER_SRC" ]; then
    PROVIDER_FILE="$MODULE_DIR/ministack-provider.tf"
    cp "$PROVIDER_SRC" "$PROVIDER_FILE"
  fi

  set +e
  (
    cd "$MODULE_DIR"
    echo -e "${GRAY}Inicializando...${NC}"
    terraform init -backend=false >/dev/null 2>&1
    INIT_RC=$?
    if [ $INIT_RC -ne 0 ]; then
      echo -e "${RED}tflocal/terraform init falló${NC}"
      exit 1
    fi
    echo -e "${GRAY}Ejecutando tests...${NC}"
    terraform test 2>&1
  )
  RC=$?
  set -e

  # Limpiar provider temporal si lo creamos
  if [ -n "$PROVIDER_SRC" ] && [ -f "$PROVIDER_FILE" ]; then
    # Solo borrar si lo creamos nosotros (comparar con src)
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
