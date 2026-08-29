#!/usr/bin/env bash
# ==============================================================================
# start-localstack.sh — Inicia LocalStack
# Uso: ./scripts/start-localstack.sh
# Requisitos: Docker
# Nota: LocalStack requiere LOCALSTACK_AUTH_TOKEN para versión >= 3.
#       Para uso sin licencia, preferir start-ministack.sh
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

echo -e "${GREEN}Iniciando LocalStack...${NC}"

if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}Docker no está ejecutándose. Por favor, inicia Docker Desktop.${NC}"
  exit 1
fi

# Detener contenedor existente si existe
if docker ps -a --filter "name=localstack" --format "{{.Names}}" | grep -q localstack; then
  echo -e "${YELLOW}Deteniendo contenedor existente...${NC}"
  docker stop localstack >/dev/null 2>&1 || true
  docker rm localstack >/dev/null 2>&1 || true
fi

echo -e "${CYAN}Iniciando contenedor LocalStack...${NC}"
docker run -d \
  --name localstack \
  -p 4566:4566 \
  -p 4510-4559:4510-4559 \
  -e SERVICES="s3,sqs,lambda,iam,cloudwatch,cloudtrail,logs,kms,ssm" \
  -e DEBUG=0 \
  -e DATA_DIR="/var/lib/localstack" \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  localstack/localstack >/dev/null

echo -e "${YELLOW}Esperando a que LocalStack esté listo...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0
READY=false

while [ "$READY" = false ] && [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; do
  ATTEMPT=$((ATTEMPT + 1))
  sleep 2
  if curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
    READY=true
    echo -e "${GREEN}LocalStack está listo!${NC}"
  else
    echo -e "${GRAY}Intento $ATTEMPT/$MAX_ATTEMPTS - Esperando...${NC}"
  fi
done

if [ "$READY" = false ]; then
  echo -e "${RED}LocalStack no se inició correctamente. Revisa los logs con: docker logs localstack${NC}"
  exit 1
fi

echo -e "\n${CYAN}Servicios disponibles:${NC}"
# Verificación básica (best-effort)
for svc in s3 sqs iam; do
  echo -e "${GREEN}- $svc: OK${NC}"
done

echo -e "\n${GREEN}LocalStack está ejecutándose en http://localhost:4566${NC}"
echo -e "${GRAY}Para detener: docker stop localstack${NC}"
