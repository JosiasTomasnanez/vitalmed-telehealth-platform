#!/usr/bin/env bash

# Colores para la consola
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m' # Sin color

echo -e "${CYAN}=== Iniciando MiniStack ===${NC}"

# Verificar que Docker está ejecutándose
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker no está ejecutándose. Por favor, inicia el demonio de Docker / Docker Desktop.${NC}"
    exit 1
fi

# Verificar si ya está corriendo
RUNNING=$(docker ps --filter "name=^ministack$" --format "{{.Names}}")
if [ -n "$RUNNING" ]; then
    echo -e "${GREEN}MiniStack ya está ejecutándose${NC}"
    if curl -s -f "http://localhost:4566/_ministack/health" > /dev/null 2>&1; then
        echo -e "${GREEN}Health check OK${NC}"
        exit 0
    else
        echo -e "${YELLOW}Reiniciando MiniStack...${NC}"
        docker stop ministack > /dev/null 2>&1
        docker rm ministack > /dev/null 2>&1
    fi
fi

# Iniciar MiniStack
echo -e "${CYAN}Iniciando contenedor MiniStack...${NC}"
docker run -d \
    --name ministack \
    -p 4566:4566 \
    ministackorg/ministack

# Esperar a que MiniStack esté listo
echo -e "${YELLOW}Esperando a que MiniStack esté listo...${NC}"
MAX_ATTEMPTS=15
ATTEMPT=0
READY=false

while [ "$READY" = false ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
    
    HEALTH_BODY=$(curl -s "http://localhost:4566/_ministack/health" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$HEALTH_BODY" ]; then
        READY=true
        echo -e "${GREEN}¡MiniStack está listo!${NC}"
    else
        echo -e "${GRAY}Intento ${ATTEMPT}/${MAX_ATTEMPTS} - Esperando...${NC}"
    fi
done

if [ "$READY" = false ]; then
    echo -e "${RED}MiniStack no se inició correctamente. Revisa los logs con: docker logs ministack${NC}"
    exit 1
fi

# Verificar servicios clave
echo -e "\n${CYAN}Servicios disponibles:${NC}"
SERVICES=("ec2" "s3" "sqs" "lambda" "iam" "cloudwatch" "logs" "kms" "ssm")

for svc in "${SERVICES[@]}"; do
    if echo "$HEALTH_BODY" | grep -q "\"$svc\":[[:space:]]*\"available\""; then
        echo -e "  ${GREEN}✓ ${svc}${NC}"
    else
        echo -e "  ${RED}✗ ${svc} (no disponible)${NC}"
    fi
done

echo -e "\n${GREEN}MiniStack está ejecutándose en http://localhost:4566${NC}"
echo -e "${GRAY}Para detener: docker stop ministack${NC}"
