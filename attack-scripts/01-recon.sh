#!/bin/bash
# ============================================================
# DEMO SCRIPT 01 — Reconocimiento
# HackGDL: Exploit the Invisible
# ============================================================

TARGET_HOST="${1:-crapi-web}"
TARGET_PORT="${2:-80}"
BASE="http://${TARGET_HOST}:${TARGET_PORT}"

echo "=============================================="
echo " FASE 1: RECONOCIMIENTO"
echo " Target: ${TARGET_HOST}:${TARGET_PORT}"
echo "=============================================="
echo ""

# ── 1.1 nmap ─────────────────────────────────────────────────
echo "[*] Iniciando nmap..."
echo ""
nmap -sV -p "${TARGET_PORT}" "${TARGET_HOST}" --open

echo ""
echo "----------------------------------------------"
echo "[*] PASO 1: Descubriendo servicios / prefijos..."
echo "----------------------------------------------"
echo ""

# Wordlist de prefijos de servicios comunes en APIs
cat > /tmp/prefixes.txt << 'EOF'
identity
community
workshop
api
v1
v2
health
docs
swagger
admin
auth
chatbot
gateway
EOF

ffuf \
  -u "${BASE}/FUZZ" \
  -w /tmp/prefixes.txt \
  -mc 200,301,302,401,403,404 \
  -fc 404 \
  -t 20 \
  -c \
  -s 2>/dev/null

echo ""
echo "----------------------------------------------"
echo "[*] PASO 2: Enumerando endpoints por servicio..."
echo "----------------------------------------------"
echo ""

# Wordlist de endpoints de API comunes (SecLists si está disponible)
SECLISTS_API="/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt"
SECLISTS_RAFT="/usr/share/seclists/Discovery/Web-Content/raft-small-words.txt"

# Wordlist crAPI-específica (endpoints reales + rutas de interés para demo)
cat > /tmp/crapi-paths.txt << 'EOF'
api/auth/login
api/auth/signup
api/auth/forget-password
api/auth/v3/check-otp
api/v2/user/dashboard
api/v2/user/change-email
api/v2/user/change-phone-number
api/v2/user/pictures
api/v2/vehicle
api/v2/vehicle/add_vehicle
api/v2/coupon/validate-coupon
api/v2/mechanic
api/v2/mechanic/service_requests
api/v2/community/posts
api/v2/community/posts/recent
api/v2/admin/videos
api/v2/admin/users
health_check
EOF

if [ -f "$SECLISTS_API" ]; then
  # Combinar SecLists + paths específicos de crAPI
  cat "$SECLISTS_API" /tmp/crapi-paths.txt | sort -u > /tmp/combined-wordlist.txt
  WORDLIST="/tmp/combined-wordlist.txt"
  echo "[*] Usando SecLists + wordlist crAPI ($(wc -l < "$WORDLIST") paths)"
else
  WORDLIST="/tmp/crapi-paths.txt"
  echo "[*] Usando wordlist local"
fi

# Fuzzear bajo cada prefijo de servicio
# -fs 49 filtra respuestas genéricas del proxy (rutas inexistentes → 401, 49 bytes)
for PREFIX in identity community workshop; do
  echo ""
  echo "  [>] Fuzzeando /${PREFIX}/..."
  echo ""
  ffuf \
    -u "${BASE}/${PREFIX}/FUZZ" \
    -w "$WORDLIST" \
    -mc 200,201,301,302,401,403,405 \
    -fs 49 \
    -t 30 \
    -c 2>/dev/null
done

echo ""
echo "[✓] Reconocimiento completo."
echo "    Endpoints encontrados listos para explotar."
echo "    Siguiente: ./02-exploit-bola.sh"
