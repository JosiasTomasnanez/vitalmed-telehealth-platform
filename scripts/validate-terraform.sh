#!/usr/bin/env bash
# ==============================================================================
# validate-terraform.sh — Valida Terraform sin credenciales AWS
# Uso: ./scripts/validate-terraform.sh
# Requisitos: terraform >= 1.10 en PATH
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

# Directorio raíz del proyecto (relativo al script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${CYAN}=== Validacion de Terraform ===${NC}"

if ! command -v terraform >/dev/null 2>&1; then
  echo -e "${RED}terraform no encontrado en PATH${NC}"
  exit 1
fi

echo -e "${GREEN}Terraform: $(terraform version | head -n1)${NC}"

# 1. Formateo
echo -e "\n${YELLOW}1. Verificando formateo...${NC}"
if terraform fmt -check -recursive >/dev/null 2>&1; then
  echo -e "  ${GREEN}Formateo correcto${NC}"
else
  echo -e "  ${YELLOW}Archivos con formato incorrecto, aplicando fmt...${NC}"
  terraform fmt -recursive >/dev/null
fi

# 2. Validación de módulos
echo -e "\n${YELLOW}2. Validando modulos...${NC}"
MODULES=("network" "compute" "data" "edge" "async")
for mod in "${MODULES[@]}"; do
  MOD_PATH="$PROJECT_ROOT/terraform/modules/$mod"
  echo -e "  ${GRAY}Modulo: $mod${NC}"
  if [ ! -d "$MOD_PATH" ]; then
    echo -e "  ${YELLOW}Directorio no encontrado: $MOD_PATH${NC}"
    continue
  fi
  (
    cd "$MOD_PATH"
    terraform init -backend=false >/dev/null 2>&1 || true
    RESULT=$(terraform validate 2>&1 || true)
    if echo "$RESULT" | grep -q "is valid"; then
      echo -e "  ${GREEN}$mod valido${NC}"
    else
      echo -e "  ${RED}$mod invalido${NC}"
      echo "$RESULT" | sed 's/^/    /'
    fi
  )
done

# 3. Validación de environments
echo -e "\n${YELLOW}3. Validando environments...${NC}"
ENVIRONMENTS=("ar/preprod" "ar/prod" "cl/preprod" "cl/prod" "co/preprod" "co/prod" "mx/preprod" "mx/prod")
for env_name in "${ENVIRONMENTS[@]}"; do
  ENV_PATH="$PROJECT_ROOT/terraform/environments/$env_name"
  echo -e "  ${GRAY}Environment: $env_name${NC}"
  if [ ! -d "$ENV_PATH" ]; then
    echo -e "  ${YELLOW}Directorio no encontrado${NC}"
    continue
  fi
  (
    cd "$ENV_PATH"
    terraform init -backend=false >/dev/null 2>&1 || true
    RESULT=$(terraform validate 2>&1 || true)
    if echo "$RESULT" | grep -q "is valid"; then
      echo -e "  ${GREEN}$env_name valido${NC}"
    else
      echo -e "  ${RED}$env_name invalido${NC}"
      echo "$RESULT" | sed 's/^/    /'
    fi
  )
done

echo -e "\n${CYAN}=== Validacion completada ===${NC}"
