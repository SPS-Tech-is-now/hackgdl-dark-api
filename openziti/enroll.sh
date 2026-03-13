#!/bin/bash
# ============================================================
# Enrollment de identidades ZT con NetFoundry
# Ejecutar UNA SOLA VEZ — genera los .json de identidad
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=============================================="
echo " Enrolling crapi-host..."
echo "=============================================="
docker run --rm \
  -v "${SCRIPT_DIR}:/config" \
  openziti/ziti-edge-tunnel:latest \
  enroll --jwt /config/crapi-host.jwt --identity /config/crapi-host.json

echo ""
echo "=============================================="
echo " Enrolling demo-client..."
echo "=============================================="
docker run --rm \
  -v "${SCRIPT_DIR}:/config" \
  openziti/ziti-edge-tunnel:latest \
  enroll --jwt /config/demo-client.jwt --identity /config/demo-client.json

echo ""
echo "=============================================="
if [ -f "${SCRIPT_DIR}/crapi-host.json" ] && [ -f "${SCRIPT_DIR}/demo-client.json" ]; then
  echo "[✓] Enrollment completo."
  echo "    Archivos generados:"
  echo "    - crapi-host.json"
  echo "    - demo-client.json"
  echo ""
  echo "    Siguiente: docker-compose up -d"
else
  echo "[!] ERROR: Uno o ambos archivos .json no se generaron."
  echo "    Verifica que los JWT sean válidos y no hayan expirado."
fi
echo "=============================================="
