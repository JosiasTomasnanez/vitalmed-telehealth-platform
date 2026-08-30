#!/usr/bin/env bash

# Colores para la consola
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # Sin color

echo -e "${GREEN}Iniciando LocalStack...${NC}"

# Verificar que Docker está ejecutándose
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker no está ejecutándose. Por favor, inicia el demonio de Docker / Docker Desktop.${NC}"
    exit 1
fi

# Detener y remover contenedor existente si existe
if docker ps -a --format '{{.Names}}' | grep -q "^localstack$"; then
    echo -e "${YELLOW}Deteniendo contenedor existente...${NC}"
    docker stop localstack > /dev/null 2>&1
    docker rm localstack > /dev/null 2>&1
fi

# Iniciar LocalStack
echo -e "${CYAN}Iniciando contenedor LocalStack...${NC}"
docker run -d \
    --name localstack \
    -p 4566:4566 \
    -p 4510-4559:4510-4559 \
    -e SERVICES="s3,sqs,lambda,iam,cloudwatch,cloudtrail,logs,kms,ssm" \
    -e DEBUG=0 \
    -e DATA_DIR="/var/lib/localstack" \
    -e DOCKER_HOST=unix:///var/run/docker.sock \
    localstack/localstack

# Esperar a que LocalStack esté listo
echo -e "${YELLOW}Esperando a que LocalStack esté listo...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0
READY=false

while [ "$READY" = false ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
    
    if curl -s -f "http://localhost:4566/_localstack/health" > /dev/null 2>&1; then
        READY=true
        echo -e "${GREEN}¡LocalStack está listo!${NC}"
    else
        echo -e "${GRAY}Intento ${ATTEMPT}/${MAX_ATTEMPTS} - Esperando...${NC}"
    fi
done

if [ "$READY" = false ]; then
    echo -e "${RED}LocalStack no se inició correctamente. Revisa los logs con: docker logs localstack${NC}"
    exit 1
fi

# Verificar servicios
echo -e "\n${CYAN}Servicios disponibles:${NC}"
docker exec localstack aws --endpoint-url=http://localhost:4566 s3 ls > /dev/null 2>&1 && echo -e "${GREEN}- S3: OK${NC}"
docker exec localstack aws --endpoint-url=http://localhost:4566 sqs list-queues > /dev/null 2>&1 && echo -e "${GREEN}- SQS: OK${NC}"
docker exec localstack aws --endpoint-url=http://localhost:4566 iam list-roles > /dev/null 2>&1 && echo -e "${GREEN}- IAM: OK${NC}"

echo -e "\n${GREEN}LocalStack está ejecutándose en http://localhost:4566${NC}"
echo -e "${GRAY}Para detener: docker stop localstack${NC}"
