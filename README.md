# Exploit the Invisible — Dark APIs & Zero Trust

> **HackGDL 2026** · Demo de la charla: *"Exploit the Invisible: Demostrando Por Qué las Dark APIs Rompen el Playbook Ofensivo"*

Este repositorio contiene el setup completo para una demo en vivo que contrasta atacar una API pública vulnerable contra la misma API corriendo como un **Dark Service de Zero Trust** — donde la superficie de ataque es literalmente cero.

---

## El Concepto

Un playbook ofensivo estándar (reconocimiento → enumeración → explotación) depende de una sola suposición: **el objetivo es alcanzable**. La arquitectura Zero Trust con Dark Services rompe esa suposición en la capa 0.

```
API Pública                         Dark Service (Zero Trust)
─────────────────────────           ──────────────────────────────
Internet → Puerto 443 abierto       Internet → nada
nmap → puertos encontrados    vs.   nmap → 0 hosts activos
ffuf → endpoints descubiertos       ffuf → 0 respuestas
curl → respuesta HTTP               curl → Connection failed
exploit → funciona                  exploit → falla en el paso 1
```

La **misma API vulnerable**, los **mismos scripts de ataque** — solo cambia la exposición en la red.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│  Red Docker: crapi_default                                  │
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
                  (resuelve via fabric ZT)           (NXDOMAIN — invisible)
```

- `ziti-host` se conecta **saliente** a NetFoundry — no abre ningún puerto de entrada
- `dark.crapi.hackgdl` no existe en ningún DNS público
- **Atacante** (sin identidad): DNS falla, HTTP falla, TCP scan falla — superficie de ataque = CERO
- **dark-client.jar** (identidad enrollada): resuelve y conecta via fabric ZT — HTTP 200

---

## Componentes

| Componente | Descripción |
|------------|-------------|
| `crapi/` | [crAPI](https://github.com/OWASP/crAPI) — API intencionalmente vulnerable de OWASP, corre en `localhost:8888` |
| `attack-scripts/` | Scripts Bash (ejecutados dentro del contenedor Kali) que demuestran el OWASP API Top 10 |
| `openziti/` | Docker Compose para `ziti-host`, que registra crAPI como Dark Service en NetFoundry |
| `dark-client/` | Fat JAR en Java con el SDK de OpenZiti para acceder al Dark Service con identidad ZT |
| `slides/` | Presentación Reveal.js (18 slides) — abrir `slides/index.html` en cualquier browser |

---

## Inicio Rápido

### Prerequisitos

- Docker Desktop
- Java 11+ (para el dark-client)
- Maven (para compilar el dark-client)
- Archivo de identidad NetFoundry / OpenZiti (`.json`) para la demo del Dark Service

### 1 — Levantar crAPI (el objetivo vulnerable)

```bash
cd crapi
docker-compose up -d
```

Verificar:
- http://localhost:8888 — crAPI UI
- http://localhost:8025 — MailHog (correo)

### 2 — Levantar el Dark Service (OpenZiti)

> Levantar crAPI primero — `ziti-host` se une a la red Docker `crapi_default`.

```bash
cd openziti
docker-compose up -d
docker logs ziti-host --tail 20
# Buscar: "edge connection established"
```

### 3 — Construir la imagen Kali (atacante)

```bash
cd attack-scripts
docker build -f Dockerfile.attacker -t hackgdl-attacker .
```

### 4 — Ejecutar los scripts de ataque (contenedor Kali)

```bash
docker run -it --rm \
  --network crapi_default \
  --name kali-attacker \
  -v $(pwd)/attack-scripts:/scripts \
  hackgdl-attacker /bin/bash
```

Dentro del contenedor, ejecutar los scripts en orden:

```bash
bash /scripts/01-recon.sh         # nmap + ffuf — descubre puertos y endpoints
bash /scripts/02-exploit-bola.sh  # BOLA/IDOR — lee GPS de la víctima sin autorización
bash /scripts/03-bruteforce.sh    # Sin rate limiting — fuerza bruta a la contraseña
bash /scripts/04-data-exposure.sh # Exposición excesiva — emails, vehicleIds, pincodes
bash /scripts/05-dark-api-fail.sh # Mismo playbook contra la Dark API — todo falla
```

### 5 — Java Dark Client (acceso Zero Trust autorizado)

#### Compilar

```bat
cd dark-client
build.bat
```

#### Ejecutar

```bat
# Simular atacante (sin identidad ZT) — todo falla
run.bat --attacker

# Listar servicios ZT accesibles
run.bat C:\ruta\a\myConsumer.json --list

# Acceder al Dark Service (por defecto: /health)
run.bat C:\ruta\a\myConsumer.json crapi-dark

# Acceder a un endpoint específico
run.bat C:\ruta\a\myConsumer.json crapi-dark /community/api/v2/community/posts
```

La salida es estilo `curl -v`, mostrando el intercambio HTTP completo a través del fabric ZT.

---

## Flujo de la Demo (Estructura de la Charla)

| Fase | Duración | Qué ocurre |
|------|----------|------------|
| Hook | 0:00–0:02 | `nmap` devuelve nada contra la Dark API — se crea intriga |
| Contexto | 0:02–0:04 | OWASP API Top 10, por qué la exposición es el problema raíz |
| **DEMO 1** — Ataques a la API pública | 0:04–0:11 | Scripts 01–04: reconocimiento, BOLA, fuerza bruta, exposición de datos |
| Concepto Zero Trust | 0:11–0:14 | Slides de arquitectura: API pública vs. Dark Service |
| **DEMO 2** — La Dark API resiste | 0:14–0:17 | Script 05 + dark-client: mismos ataques, cero resultados |
| Implementación | 0:17–0:19 | Cómo hacerlo tú mismo con OpenZiti |
| Conclusiones + Q&A | 0:19–0:20 | 4 puntos clave |

---

## Descripción de los Scripts de Ataque

### `01-recon.sh` — Reconocimiento
Usa `nmap` y `ffuf` para descubrir puertos abiertos y enumerar endpoints de la API. Muestra lo trivial que es mapear la superficie de una API pública.

### `02-exploit-bola.sh` — BOLA / IDOR
Extrae `vehicleId` de los posts públicos de la comunidad y consulta la ubicación GPS de vehículos de la víctima sin autorización. Demuestra **OWASP API1:2023**.

### `03-bruteforce.sh` — Sin Rate Limiting
Dispara 20 intentos de login en rápida sucesión — sin bloqueo, sin captcha. Encuentra la contraseña de la víctima en el intento #8. Demuestra **OWASP API4:2023**.

### `04-data-exposure.sh` — Exposición Excesiva de Datos
Los posts públicos exponen `email`, `vehicleId` y campos internos. El endpoint de cupones filtra montos e información interna. Demuestra **OWASP API3:2023**.

### `05-dark-api-fail.sh` — El Playbook Falla
Ejecuta la misma secuencia contra `dark.crapi.hackgdl`:
- `nslookup` → NXDOMAIN
- `nmap` → 0 hosts activos
- `curl` → Connection failed
- `ffuf` → 0 respuestas

**El playbook ofensivo colapsa en el paso 1. Superficie de ataque = CERO.**

---

## Usuarios de Demo

| Rol | Email | Contraseña |
|-----|-------|------------|
| Atacante | attacker@test.com | Password1@ |
| Víctima | victim@hackgdl.mx | Password1@ |

| Usuario | VIN | UUID del Vehículo |
|---------|-----|-------------------|
| victim@hackgdl.mx | S61ZUHHDB60F6K007 | 88ee25b0-e084-4eee-a0f9-45721e892333 |
| attacker@test.com | FR86324S5VKPN8H37 | 71bd7cdc-cbe8-4a39-a856-c6eb3704f74a |

### Setup Inicial (solo la primera vez)

```bash
# Registrar usuarios
curl -s -X POST http://localhost:8888/identity/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"Attacker","email":"attacker@test.com","number":"3312345678","password":"Password1@"}'

curl -s -X POST http://localhost:8888/identity/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"Victim User","email":"victim@hackgdl.mx","number":"3398765432","password":"Password1@"}'
```

Activar ambas cuentas en http://localhost:8025 (clic en el link de cada email).

```bash
# Asignar vehículos en la DB
docker exec postgresdb psql -U admin -d crapi \
  -c "UPDATE vehicle_details SET owner_id = 10 WHERE vin = 'S61ZUHHDB60F6K007';"
docker exec postgresdb psql -U admin -d crapi \
  -c "UPDATE vehicle_details SET owner_id = 9  WHERE vin = 'FR86324S5VKPN8H37';"
```

---

## Persistencia de Datos

Los datos de demo (usuarios, vehículos, posts) persisten en volúmenes Docker nombrados.

```bash
# ✅ Baja contenedores, conserva datos
docker-compose down

# ❌ Borra todo — requiere setup completo de nuevo
docker-compose down -v
```

---

## Orden de Inicio y Parada

La red Docker requiere un orden específico:

**Iniciar:** crAPI primero → luego openziti (`ziti-host` se une a la red `crapi_default`)

**Detener:** openziti primero → luego crAPI (libera la red antes de eliminarla)

```bash
# Detener
cd openziti && docker-compose down
cd ../crapi && docker-compose down

# Iniciar
cd crapi && docker-compose up -d
cd ../openziti && docker-compose up -d
```

---

## Tecnologías

- **[crAPI](https://github.com/OWASP/crAPI)** — API intencionalmente vulnerable de OWASP
- **[OpenZiti](https://openziti.io)** / **[NetFoundry](https://netfoundry.io)** — Red overlay de Zero Trust
- **[Reveal.js](https://revealjs.com)** — Framework de presentaciones
- **Java + OpenZiti SDK** — Cliente dark con identidad ZT embebida
- **Docker** — Stack de crAPI + contenedor atacante Kali
- **ffuf, nmap** — Herramientas ofensivas (dentro del contenedor Kali)

---

## Conclusión Clave

> *"Si tu API no existe en la red, no puede ser atacada."*

Los Dark Services de Zero Trust no agregan simplemente otra capa de seguridad — eliminan la superficie de ataque por completo. La misma API, las mismas vulnerabilidades en el código, pero el playbook ofensivo falla en el paso 1: **el reconocimiento**.

---

## Licencia

MIT — uso demo/educativo. crAPI es © OWASP Foundation bajo su propia licencia.
