#!/bin/bash
# ============================================================
# DEMO SCRIPT 05 — El Playbook FALLA contra la Dark API
# HackGDL: Exploit the Invisible
#
# IMPORTANTE: Ejecutar desde Windows cmd/PowerShell
# con el cliente NetFoundry DESACTIVADO.
# Eso simula al atacante externo sin identidad ZT.
# ============================================================

DARK_HOST="${1:-dark.crapi.hackgdl}"
DARK_PORT="${2:-80}"

echo "=============================================="
echo " FASE 5: EL MISMO PLAYBOOK vs. DARK API"
echo " Dark API Host: ${DARK_HOST}"
echo " Atacante: externo, sin identidad Zero Trust"
echo "=============================================="
echo ""

print_separator() {
  echo ""
  echo "  ═══════════════════════════════════════"
  echo "  $1"
  echo "  ═══════════════════════════════════════"
  echo ""
}

# ── ATAQUE 1: DNS Lookup ─────────────────────────────────────
print_separator "ATAQUE 1: DNS Lookup"

echo "[*] Intentando resolver: ${DARK_HOST}"
echo ""
DNS_RESULT=$(nslookup "${DARK_HOST}" 2>&1)
echo "$DNS_RESULT"

if echo "$DNS_RESULT" | grep -qiE "NXDOMAIN|can't find|server failed|SERVFAIL"; then
  echo ""
  echo "[✗] RESULTADO: NXDOMAIN — el host no existe en DNS público"
else
  echo ""
  echo "[!] DNS resolvió (posiblemente cliente ZT activo o red interna)"
fi

# ── ATAQUE 2: nmap ───────────────────────────────────────────
print_separator "ATAQUE 2: nmap port scan"

echo "[*] Ejecutando: nmap -sV -p ${DARK_PORT},443 ${DARK_HOST}"
echo ""
NMAP_RESULT=$(timeout 20 nmap -sV -p "${DARK_PORT},443" "${DARK_HOST}" 2>&1)
echo "$NMAP_RESULT"

if echo "$NMAP_RESULT" | grep -q "0 hosts up\|host down\|Failed to resolve"; then
  echo ""
  echo "[✗] RESULTADO: Sin host. Sin puertos. Nada."
else
  echo ""
  echo "[!] nmap encontró algo — verificar configuración del demo"
fi

# ── ATAQUE 3: HTTP directo ───────────────────────────────────
print_separator "ATAQUE 3: curl (HTTP directo)"

echo "[*] Ejecutando: curl --connect-timeout 5 http://${DARK_HOST}/"
echo ""
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${DARK_HOST}/" 2>&1)
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ] || [ "$HTTP_CODE" = "000" ]; then
  echo "  curl: ($CURL_EXIT) Connection failed"
  echo ""
  echo "[✗] RESULTADO: Sin respuesta HTTP. El servidor no existe."
else
  echo "  HTTP $HTTP_CODE recibido"
  echo ""
  echo "[!] Conexión exitosa — verificar que el cliente ZT esté DESACTIVADO"
fi

# ── ATAQUE 4: ffuf ───────────────────────────────────────────
print_separator "ATAQUE 4: ffuf (endpoint enumeration)"

echo "[*] Fuzzeando endpoints en http://${DARK_HOST}/..."
echo ""

cat > /tmp/dark-wordlist.txt << 'EOF'
api
login
health
identity
community
workshop
EOF

# Pre-check DNS: si el host no resuelve, ffuf se colgará esperando TCP.
# Lo omitimos directamente y mostramos el resultado esperado.
DNS_CHECK=$(nslookup "${DARK_HOST}" 2>&1)
if echo "$DNS_CHECK" | grep -qiE "NXDOMAIN|can't find|server failed|SERVFAIL"; then
  echo "  [✗] ffuf: DNS NXDOMAIN — host invisible, sin endpoints que enumerar"
else
  FFUF_RESULT=$(timeout 10 ffuf \
    -u "http://${DARK_HOST}/FUZZ" \
    -w /tmp/dark-wordlist.txt \
    -mc 200,401,403 \
    -t 2 \
    -timeout 3 \
    -s 2>&1)

  if [ -z "$FFUF_RESULT" ]; then
    echo "  [✗] ffuf: 0 respuestas — sin endpoints que enumerar"
  else
    echo "$FFUF_RESULT"
    echo "  [!] Endpoints encontrados — verificar configuración"
  fi
fi

# ── RESUMEN ─────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "  RESUMEN — API Pública vs. Dark Service"
echo "══════════════════════════════════════════════"
echo ""
echo "  Técnica            | API Pública  | Dark Service"
echo "  ───────────────────────────────────────────────"
echo "  nmap port scan     | Puerto 80    | Sin host"
echo "  DNS lookup         | IP pública   | NXDOMAIN"
echo "  HTTP directo       | 200 OK       | Connection failed"
echo "  Endpoint enum      | 8 endpoints  | 0 respuestas"
echo ""
echo "  El playbook ofensivo falla en el PRIMER PASO."
echo "  La superficie de ataque es CERO."
echo ""

# ── Acceso legítimo ──────────────────────────────────────────
echo "══════════════════════════════════════════════"
echo "  CONTRASTE: Acceso legítimo con identidad ZT"
echo "══════════════════════════════════════════════"
echo ""
echo "  Paso 1: Activa el cliente NetFoundry en Windows"
echo ""
echo "  Paso 2: ejecuta en tu terminal:"
echo ""
echo "    curl -s -o /dev/null -w \"%{http_code}\" http://${DARK_HOST}/health"
echo ""
echo "  Resultado esperado con identidad ZT activa:"
echo "    → 200"
echo ""
