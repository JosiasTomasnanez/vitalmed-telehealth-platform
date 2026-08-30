#!/usr/bin/env bash

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

echo -e "${CYAN}=== Validacion de Terraform ===${NC}"

if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version 2>&1 | head -n 1)
    echo -e "${GREEN}Terraform: ${TF_VERSION}${NC}"
else
    echo -e "${RED}Error: terraform no está instalado.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}1. Verificando formateo...${NC}"
if terraform fmt -check -recursive "${PROJECT_ROOT}/terraform" > /dev/null 2>&1; then
    echo -e "   ${GREEN}Formateo correcto${NC}"
else
    echo -e "   ${YELLOW}Archivos con formato incorrecto, aplicando fmt...${NC}"
    terraform fmt -recursive "${PROJECT_ROOT}/terraform"
fi

ORIGINAL_DIR="$(pwd)"

echo -e "\n${YELLOW}2. Validando modulos...${NC}"
MODULES=("network" "compute" "data" "edge" "async")

for mod in "${MODULES[@]}"; do
    MOD_PATH="${PROJECT_ROOT}/terraform/modules/${mod}"
    echo -e "   ${GRAY}Modulo: ${mod}${NC}"
    
    if [ ! -d "$MOD_PATH" ]; then
        echo -e "   ${YELLOW}Directorio no encontrado${NC}"
        continue
    fi
    
    cd "$MOD_PATH" || continue
    
    INIT_OUTPUT=$(terraform init -backend=false 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "   ${RED}✗ Error durante 'terraform init' en módulo ${mod}:${NC}"
        echo "$INIT_OUTPUT" | sed 's/^/      /'
        cd "$ORIGINAL_DIR" || exit 1
        continue
    fi

    VALIDATE_OUTPUT=$(terraform validate 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓ ${mod} valido${NC}"
    else
        echo -e "   ${RED}✗ ${mod} invalido:${NC}"
        echo "$VALIDATE_OUTPUT" | sed 's/^/      /'
    fi
    
    cd "$ORIGINAL_DIR" || exit 1
done

echo -e "\n${YELLOW}3. Validando environments (detección dinámica)...${NC}"
ENV_BASE_PATH="${PROJECT_ROOT}/terraform/environments"

if [ -d "$ENV_BASE_PATH" ]; then
    # Encuentra dinámicamente cualquier carpeta que contenga main.tf
    find "$ENV_BASE_PATH" -type f -name "main.tf" | while read -r main_file; do
        ENV_DIR=$(dirname "$main_file")
        ENV_REL_PATH="${ENV_DIR#$ENV_BASE_PATH/}"
        
        echo -e "   ${GRAY}Environment: ${ENV_REL_PATH}${NC}"
        
        cd "$ENV_DIR" || continue
        
        INIT_OUTPUT=$(terraform init -backend=false 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "   ${RED}✗ Error durante 'terraform init' en ${ENV_REL_PATH}:${NC}"
            echo "$INIT_OUTPUT" | sed 's/^/      /'
            cd "$ORIGINAL_DIR" || exit 1
            continue
        fi

        VALIDATE_OUTPUT=$(terraform validate 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "   ${GREEN}✓ ${ENV_REL_PATH} valido${NC}"
        else
            echo -e "   ${RED}✗ ${ENV_REL_PATH} invalido:${NC}"
            echo "$VALIDATE_OUTPUT" | sed 's/^/      /'
        fi
        
        cd "$ORIGINAL_DIR" || exit 1
    done
else
    echo -e "   ${YELLOW}Directorio de environments no encontrado.${NC}"
fi

echo -e "\n${CYAN}=== Validacion completada ===${NC}"
