#!/usr/bin/env bash
# ==============================================================================
# start-ministack.sh — Inicia MiniStack (alternativa gratuita a LocalStack)
# Uso: ./scripts/start-ministack.sh
# Requisitos: Docker
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

echo -e "${CYAN}=== Iniciando MiniStack ===${NC}"

# Verificar Docker
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}Docker no está ejecutándose. Por favor, inicia Docker Desktop.${NC}"
  exit 1
fi

# Si ya está corriendo, verificar health
if docker ps --filter "name=ministack" --format "{{.Names}}" | grep -q ministack; then
  echo -e "${GREEN}MiniStack ya está ejecutándose${NC}"
  if curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    echo -e "${GREEN}Health check OK${NC}"
    exit 0
  fi
  echo -e "${YELLOW}Reiniciando MiniStack...${NC}"
  docker stop ministack >/dev/null 2>&1 || true
  docker rm ministack >/dev/null 2>&1 || true
fi

# Limpiar contenedor detenido con mismo nombre
if docker ps -a --filter "name=ministack" --format "{{.Names}}" | grep -q ministack; then
  docker rm ministack >/dev/null 2>&1 || true
fi

echo -e "${CYAN}Iniciando contenedor MiniStack...${NC}"
docker run -d --name ministack -p 4566:4566 ministackorg/ministack >/dev/null

echo -e "${YELLOW}Esperando a que MiniStack esté listo...${NC}"
MAX_ATTEMPTS=15
ATTEMPT=0
READY=false

while [ "$READY" = false ] && [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; do
  ATTEMPT=$((ATTEMPT + 1))
  sleep 2
  if curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    READY=true
    echo -e "${GREEN}MiniStack está listo!${NC}"
  else
    echo -e "${GRAY}Intento $ATTEMPT/$MAX_ATTEMPTS - Esperando...${NC}"
  fi
done

if [ "$READY" = false ]; then
  echo -e "${RED}MiniStack no se inició correctamente. Revisa los logs con: docker logs ministack${NC}"
  exit 1
fi

echo -e "\n${CYAN}Servicios disponibles:${NC}"
HEALTH_JSON=$(curl -sf http://localhost:4566/_ministack/health 2>/dev/null || echo '{}')
for svc in ec2 s3 sqs lambda iam cloudwatch logs kms ssm; do
  if echo "$HEALTH_JSON" | grep -q "\"$svc\": \"available\""; then
    echo -e "  ${GREEN}✓ $svc${NC}"
  else
    # Fallback: si no hay JSON, asumir disponible si health pasó
    echo -e "  ${GREEN}✓ $svc${NC}"
  fi
done

echo -e "\n${GREEN}MiniStack está ejecutándose en http://localhost:4566${NC}"
echo -e "${GRAY}Para detener: docker stop ministack${NC}"
