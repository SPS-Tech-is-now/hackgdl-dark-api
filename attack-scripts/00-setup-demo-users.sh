#!/bin/bash
# ============================================================
# SETUP PREVIO — Crear usuarios de demo en crAPI
# Ejecutar ANTES de la presentación
# ============================================================

TARGET="${1:-http://crapi-web}"

echo "=============================================="
echo " SETUP: Creando usuarios de demo en crAPI"
echo " Target: $TARGET"
echo "=============================================="
echo ""

# ── Esperar a que crAPI esté listo ───────────────────────────
echo "[*] Esperando que crAPI esté disponible..."
until curl -s "${TARGET}/identity/api/auth/login" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"email":"x","password":"x"}' > /dev/null 2>&1; do
  echo "  [.] Esperando..."
  sleep 3
done
echo "[✓] crAPI está respondiendo."
echo ""

# ── Crear usuario víctima ────────────────────────────────────
echo "[*] Creando usuario VÍCTIMA..."
curl -s -X POST "${TARGET}/identity/api/auth/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Victim User",
    "email": "victim@hackgdl.mx",
    "number": "3312345678",
    "password": "Password1@"
  }' | jq '.message' 2>/dev/null
echo ""

# ── Crear usuario atacante ───────────────────────────────────
echo "[*] Creando usuario ATACANTE..."
curl -s -X POST "${TARGET}/identity/api/auth/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Attacker",
    "email": "attacker@test.com",
    "number": "3398765432",
    "password": "Password1@"
  }' | jq '.message' 2>/dev/null
echo ""

# ── Verificar emails en MailHog ──────────────────────────────
echo "[*] Verificar emails de activación en MailHog:"
echo "    http://localhost:8025"
echo ""
echo "[!] IMPORTANTE: Activar ambas cuentas via MailHog antes de la demo"
echo ""

# ── Login y crear posts de víctima (para la demo de data leakage) ──
echo "[*] Login como víctima para crear datos de demo..."
VICTIM_TOKEN=$(curl -s -X POST "${TARGET}/identity/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"victim@hackgdl.mx","password":"Password1@"}' | jq -r '.token' 2>/dev/null)

if [ -n "$VICTIM_TOKEN" ] && [ "$VICTIM_TOKEN" != "null" ]; then
  echo "[✓] Víctima autenticada"

  # Crear un post de la víctima (expone sus datos)
  curl -s -X POST "${TARGET}/community/api/v2/community/posts" \
    -H "Authorization: Bearer $VICTIM_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "Check out my new ride!",
      "content": "Just got my new car, loving it! #cars #hackgdl"
    }' | jq '.title' 2>/dev/null

  echo "[✓] Post de víctima creado (expone datos en respuesta)"
else
  echo "[!] Víctima no pudo autenticarse. Verificar activación de email."
fi

echo ""
echo "=============================================="
echo " SETUP COMPLETO"
echo "=============================================="
echo ""
echo " Checklist final:"
echo "   [ ] http://localhost:8888  — crAPI UI accesible"
echo "   [ ] http://localhost:8025  — MailHog accesible"
echo "   [ ] Cuenta victim@hackgdl.mx activada"
echo "   [ ] Cuenta attacker@test.com activada"
echo "   [ ] Post de víctima visible en community"
echo ""
echo " Cuando todo esté listo, ejecutar en orden:"
echo "   ./01-recon.sh"
echo "   ./02-exploit-bola.sh"
echo "   ./03-bruteforce.sh"
echo "   ./04-data-exposure.sh"
echo "   ./05-dark-api-fail.sh [dark-host]"
