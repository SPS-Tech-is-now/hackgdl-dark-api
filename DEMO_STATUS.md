# Demo Status — Exploit the Invisible
## HackGDL 2026

---

## Estado actual

| Componente | Estado |
|-----------|--------|
| crAPI (API vulnerable) | ✅ Funcionando en localhost:8888 |
| MailHog (email) | ✅ Funcionando en localhost:8025 |
| Kali attacker container | ✅ Imagen `hackgdl-attacker` lista |
| Script 01 — Reconocimiento | ✅ Listo y probado |
| Script 02 — BOLA/IDOR | ✅ Listo y probado |
| Script 03 — Brute force | ✅ Listo y probado |
| Script 04 — Data exposure | ✅ Listo y probado |
| Script 05 — Dark API fail | ✅ Listo (ver instrucciones abajo) |
| Slides Reveal.js | ✅ Listos (`slides/index.html`) — 18 slides |
| OpenZiti ziti-host | ✅ Conectado a NetFoundry |
| NetFoundry Dark Service | ✅ `crapi-dark` publicado, host `dark.crapi.hackgdl` |
| dark-client (Java ZT) | ✅ Compilado en `dark-client/target/dark-client.jar` |

---

## Usuarios de demo

| Usuario | Email | Password | Rol |
|---------|-------|----------|-----|
| Atacante | attacker@test.com | Password1@ | Usuario normal |
| Víctima | victim@hackgdl.mx | Password1@ | Usuario normal |

## Vehículos asignados

| Usuario | VIN | UUID |
|---------|-----|------|
| victim@hackgdl.mx | S61ZUHHDB60F6K007 | 88ee25b0-e084-4eee-a0f9-45721e892333 |
| attacker@test.com | FR86324S5VKPN8H37 | 71bd7cdc-cbe8-4a39-a856-c6eb3704f74a |

---

## Cómo ejecutar la demo completa

### 1. Levantar crAPI

```bash
cd hackgdl-dark-api/crapi
docker-compose up -d
```

Verificar en browser:
- http://localhost:8888 — crAPI UI
- http://localhost:8025 — MailHog

---

### 2. Levantar el Dark Service (OpenZiti)

```bash
cd hackgdl-dark-api/openziti
docker-compose up -d
```

Verificar que `ziti-host` esté conectado a NetFoundry:

```bash
docker logs ziti-host --tail 20
```

Buscar: `edge connection established` — confirma que el servicio está publicado.

---

### 3. Entrar al contenedor Kali (atacante)

```bash
docker run -it --rm --network crapi_default --name kali-attacker -v C:\rolando\MCPSamples\Claude\myproject\hackgdl-dark-api\attack-scripts:/scripts hackgdl-attacker /bin/bash
```

---

### 4. Scripts 01–04: Ataques a la API pública

Dentro del contenedor Kali, ejecutar en orden:

#### Script 01 — Reconocimiento
```bash
bash /scripts/01-recon.sh
```
**Qué muestra:** nmap encuentra puerto 80 + OpenResty. ffuf descubre servicios y endpoints reales (`login`, `signup`, `posts`, `coupon`...).

---

#### Script 02 — BOLA / IDOR
```bash
bash /scripts/02-exploit-bola.sh
```
**Qué muestra:** el atacante extrae vehicleIds de posts públicos y consulta la ubicación GPS de las víctimas sin autorización.

---

#### Script 03 — Sin Rate Limiting / Fuerza Bruta
```bash
bash /scripts/03-bruteforce.sh
```
**Qué muestra:** 20 requests sin un solo bloqueo. Fuerza bruta encuentra `Password1@` de la víctima en el intento #8.

---

#### Script 04 — Exposición Excesiva de Datos
```bash
bash /scripts/04-data-exposure.sh
```
**Qué muestra:** posts públicos exponen `email` + `vehicleId` de todos los usuarios. El endpoint de cupones expone datos internos (`amount`, timestamps).

---

### 5. Script 05: El mismo playbook falla contra la Dark API

Este script demuestra que **exactamente los mismos ataques fallan en el primer paso** cuando la API es un Dark Service.

#### PASO A — Atacante externo (sin identidad Zero Trust)

**En Windows: APAGAR el cliente NetFoundry Desktop.**

> Esto simula a un atacante externo que no tiene identidad ZT registrada.
> Sin el cliente, `dark.crapi.hackgdl` no existe en ningún DNS público.

Dentro del contenedor Kali (mismo contenedor del paso 3):

```bash
bash /scripts/05-dark-api-fail.sh
```

**Qué muestra:**
- `nslookup dark.crapi.hackgdl` → NXDOMAIN
- `nmap` → 0 hosts up, Failed to resolve
- `curl` → Connection failed
- `ffuf` → 0 respuestas

**Mensaje clave:** *"El playbook ofensivo falla en el PRIMER PASO. La superficie de ataque es CERO."*

---

#### PASO B — Acceso legítimo (con identidad Zero Trust)

**En Windows: usar el Java dark-client con la identidad enrollada.**

> No se necesita el NetFoundry Desktop App. El cliente Java embebe el SDK de OpenZiti y usa la identidad directamente.

```bat
cd hackgdl-dark-api\dark-client
run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark /health
```

**Qué muestra (en la misma terminal de Windows):**

```
[*] Cargando identidad ZT...
[*] Conectando al fabric OpenZiti...

> GET /health HTTP/1.1
> Host: dark.crapi.hackgdl  ← resuelto via OpenZiti (no DNS público)
> Connection: close

< HTTP/1.1 200 OK
< Content-Type: application/json
...
```

**Contraste visual:** misma máquina, misma red, solo cambia la identidad. El atacante no ve nada; el cliente ZT llega directo al servicio.

---

### 6. Java Dark Client — demo de acceso ZT en Windows

El cliente Java usa el SDK de OpenZiti para conectarse al Dark Service directamente, sin necesidad del NetFoundry Desktop App.

**Proyecto:** `hackgdl-dark-api/dark-client/`
**Identidad:** `C:\rolando\nf\sw\myConsumer.json`
**Servicio ZT:** `crapi-dark` → hostname `dark.crapi.hackgdl`

#### Compilar (solo la primera vez o si cambió código)

```bat
cd hackgdl-dark-api\dark-client
build.bat
```

Genera: `target/dark-client.jar` (fat JAR con todas las dependencias).

#### Modos de ejecución

**Modo atacante** — sin identidad, todo falla:
```bat
run.bat --attacker
```
Muestra: DNS lookup falla, HTTP falla, TCP scan falla. Misma terminal, mismo host — invisible.

**Listar servicios accesibles:**
```bat
run.bat C:\rolando\nf\sw\myConsumer.json --list
```
Muestra los servicios ZT a los que tiene acceso la identidad (`crapi-dark`).

**Modo autorizado** — path por defecto `/health`:
```bat
run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark
```

**Modo autorizado** — path específico:
```bat
run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark /community/api/v2/community/posts
```

#### Salida tipo curl-v

El cliente muestra el intercambio HTTP completo estilo `curl -v`:
```
> GET /health HTTP/1.1
> Host: dark.crapi.hackgdl
> Connection: close

< HTTP/1.1 200 OK
< Content-Type: application/json
{"status": "UP"}
```

---

### 7. Slides

Abrir en browser:
```
hackgdl-dark-api/slides/index.html
```
Navegar con `[SPACE]`. Presionar `b` para blanquear pantalla durante las demos en vivo.

#### Inventario de slides (18 en total)

| # | Sección | Título | Tipo |
|---|---------|--------|------|
| 01 | — | Exploit the Invisible (portada) | Título |
| 02 | El Escenario | Eres el atacante. Todo va bien... hasta que: | Narrativa |
| 03 | Agenda | Plan de ataque para hoy | Índice |
| 04 | Contexto | El mundo corre en APIs | Contexto |
| 05 | Target | El objetivo: crAPI | Setup |
| 06 | DEMO LIVE — FASE 1 | Reconocimiento: nmap + ffuf | Demo → `01-recon.sh` |
| 07 | DEMO LIVE — FASE 2 | BOLA — Broken Object Level Authorization | Demo → `02-exploit-bola.sh` |
| 08 | DEMO LIVE — FASE 3 y 4 | Más vulnerabilidades en minutos | Demo → `03-bruteforce.sh` + `04-data-exposure.sh` |
| 09 | Zero Trust Architecture | El problema es la exposición | SVG: API pública vs. Dark Service (2 diagramas) |
| 10 | Arquitectura de la Demo | Todos los componentes en juego | SVG: diagrama completo Docker + ZT |
| 11 | OpenZiti / NetFoundry | ¿Cómo funciona un Dark Service? | Explicación técnica |
| 12 | DEMO LIVE — El Playbook FALLA | Los mismos ataques contra la Dark API | Demo → `05-dark-api-fail.sh` |
| 13 | Cyber Kill Chain | El ataque colapsa en el PASO 1 | SVG: kill chain con muro Dark API |
| 14 | Comparativa | API Pública vs. Dark Service | Tabla comparativa |
| 15 | Implementación | Hazlo tú mismo — OpenZiti en 4 pasos | Tutorial |
| 16 | Casos de Uso | Más allá de APIs — MCPs y Agentes IA | Expansión |
| 17 | Takeaways | Para llevarse hoy | Conclusiones |
| 18 | — | ¿Preguntas? / Q&A (cierre) | Final |

---

## Setup inicial de usuarios (solo la primera vez)

Si los datos no persisten o se reinicia desde cero:

```bash
# Registrar atacante
curl -s -X POST http://localhost:8888/identity/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"Attacker","email":"attacker@test.com","number":"3312345678","password":"Password1@"}'

# Registrar víctima
curl -s -X POST http://localhost:8888/identity/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"Victim User","email":"victim@hackgdl.mx","number":"3398765432","password":"Password1@"}'
```

Activar ambas cuentas en http://localhost:8025 (clic en el link de cada email).

```bash
# Asignar vehículos en la DB
docker exec postgresdb psql -U admin -d crapi -c "UPDATE vehicle_details SET owner_id = 10 WHERE vin = 'S61ZUHHDB60F6K007';"
docker exec postgresdb psql -U admin -d crapi -c "UPDATE vehicle_details SET owner_id = 9  WHERE vin = 'FR86324S5VKPN8H37';"

# Crear post de la víctima (expone vehicleId en la community)
VICTIM_TOKEN=$(curl -s -X POST http://localhost:8888/identity/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"victim@hackgdl.mx","password":"Password1@"}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")

curl -s -X POST http://localhost:8888/community/api/v2/community/posts \
  -H "Authorization: Bearer $VICTIM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"My new car","content":"Just got my new car from the dealership, loving it"}'
```

---

## Persistencia de datos

Los datos del demo (usuarios, vehículos, posts) persisten en volúmenes Docker nombrados. Usar siempre `down` **sin** `-v`:

```bash
# ✅ Baja contenedores, conserva datos
docker-compose down

# ❌ Borra todo — requiere setup completo de nuevo
docker-compose down -v
```

Verificar volúmenes existentes:
```bash
docker volume ls | grep crapi
```

---

## Arquitectura de la demo

```
┌─────────────────────────────────────────────────────────────┐
│  Docker red: crapi_default                                  │
│                                                             │
│  crapi-web:80  ←──── ziti-host ──→ NetFoundry SaaS         │
│                                          ↑                  │
└──────────────────────────────────────────│──────────────────┘
                                           │ (overlay ZT / fabric)
                            ┌──────────────┴──────────────┐
                            │                             │
                   dark-client.jar                  Kali attacker
                   (Java + OpenZiti SDK)             (sin identidad ZT)
                   identidad: myConsumer.json
                            │                             │
                  dark.crapi.hackgdl ✅            dark.crapi.hackgdl ❌
                  (resuelve via ZT)               (NXDOMAIN — invisible)
```

- `ziti-host` se conecta **saliente** a NetFoundry — no abre puertos de entrada
- `dark.crapi.hackgdl` no existe en ningún DNS público
- **Atacante** (sin identidad): DNS falla, HTTP falla, TCP scan falla — superficie de ataque = CERO
- **dark-client.jar** (identidad enrollada): resuelve y conecta via fabric ZT — HTTP 200

---

## Requisitos previos para el día del evento

- [ ] Docker Desktop corriendo
- [ ] Contenedores crAPI levantados (`docker-compose up -d` en `/crapi`)
- [ ] Contenedor `ziti-host` levantado (`docker-compose up -d` en `/openziti`)
- [ ] Verificar `docker logs ziti-host` → `edge connection established`
- [ ] `dark-client.jar` compilado: `cd dark-client && build.bat`
- [ ] Verificar modo atacante: `run.bat --attacker` → DNS/HTTP/TCP fallan
- [ ] Verificar modo ZT: `run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark /health` → HTTP 200
- [ ] Imagen `hackgdl-attacker` lista: `docker images | grep hackgdl`
- [ ] Slides funcionando en browser: `slides/index.html`
- [ ] Puerto 8888 libre (crAPI UI)
- [ ] Puerto 8025 libre (MailHog)
- [ ] Identidad ZT disponible en `C:\rolando\nf\sw\myConsumer.json`

---

## Guía rápida — Detener y arrancar servicios

### Detener todo

> **Orden importante:** bajar primero `openziti`, luego `crapi`.
> `ziti-host` se conecta a la red `crapi_default` — si bajas crAPI primero,
> Docker no puede eliminar esa red y arroja `Error: has active endpoints`.

```bash
# 1. Salir del contenedor Kali (si está activo)
exit

# 2. Bajar ziti-host PRIMERO (libera los endpoints de crapi_default)
cd hackgdl-dark-api/openziti
docker-compose down

# 3. Bajar crAPI (ahora la red crapi_default se elimina limpiamente)
cd ../crapi
docker-compose down
```

### Arrancar todo

> **Orden importante:** arrancar primero `crapi`, luego `openziti`.
> `crapi` crea la red `crapi_default` — si arrancas `ziti-host` antes,
> no encontrará la red a la que debe conectarse.

```bash
# 1. crAPI
cd hackgdl-dark-api/crapi
docker-compose up -d

# 2. ziti-host
cd ../openziti
docker-compose up -d

# 3. Verificar que ziti-host esté conectado
docker logs ziti-host --tail 10
# Buscar: "edge connection established"

# 4. Verificar crAPI
# http://localhost:8888  → crAPI UI
# http://localhost:8025  → MailHog
```

### Verificar estado general

```bash
# Ver todos los contenedores activos
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Verificar imagen Kali disponible
docker images | grep hackgdl

# Prueba rápida del dark-client (desde Windows)
cd hackgdl-dark-api\dark-client
run.bat --attacker                                        # debe fallar todo
run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark /health  # debe responder HTTP 200
```

> **Nota:** Los datos de demo (usuarios, vehículos, posts) persisten en volúmenes Docker.
> Usar siempre `docker-compose down` **sin** `-v` para conservarlos.

---

## TODO — Pendientes

### TODO: Modo `--vehicle-demo` en dark-client

**Objetivo:** en lugar de solo llamar `/health`, ejecutar un flujo completo autenticado que muestre datos reales de vehículo de la víctima — el mismo dato que roba el script 02 (BOLA), ahora protegido por Zero Trust.

**Comando propuesto:**
```bat
run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark --vehicle-demo
```

**Flujo interno (2 requests vía ZT):**
1. `POST /identity/api/auth/login` → JWT (credenciales: `victim@hackgdl.mx` / `Password1@`)
2. `GET /identity/api/v2/vehicle/88ee25b0-e084-4eee-a0f9-45721e892333/location` + Bearer token → lat/lng, nombre, email

**Implementación:**
- Método `runVehicleDemo()` nuevo en `DarkApiClient.java`
- Usar **OkHttp** (ya en `pom.xml`) con `ZitiContext` como `SocketFactory` → enrutamiento ZT nativo, sin raw HTTP manual
- Parseo de token y GPS con regex simple (sin dependencias extra)
- Salida estilo `curl -v` para ambos requests
- Actualizar `run.bat` y banner de ayuda

**Impacto narrativo:**
- Script 02 (Kali, API pública) → extrae GPS de la víctima via BOLA ✅
- Script 05 (Kali, Dark API) → `NXDOMAIN`, ni resuelve el host ❌
- `--vehicle-demo` (dark-client, identidad ZT) → login + GPS de la víctima, 2 requests ✅

> Mismo dato, mismo ataque — la identidad ZT es el único candado que importa.
