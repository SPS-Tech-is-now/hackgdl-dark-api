# OpenZiti — Setup del Dark Service
## Para la demo de HackGDL

### Opción A: NetFoundry SaaS (Recomendada para demo)

1. Crear cuenta gratis en https://netfoundry.io
2. Crear una red en la consola
3. Configurar el servicio:
   - **Service Name:** crapi-dark
   - **Host:** localhost
   - **Port:** 8888
   - **Protocol:** TCP
4. Descargar el identity file para el tunnel

### Opción B: OpenZiti Self-Hosted (quickstart)

```bash
# Levantar controlador OpenZiti
docker run -d --name ziti-controller \
  -p 8440-8443:8440-8443 \
  openziti/quickstart

# Obtener credenciales del controlador
docker exec ziti-controller cat /persistent/pki/root-ca/certs/root-ca.cert

# Configurar el edge tunnel en el servidor de crAPI
docker run -d --name ziti-tunnel \
  --network host \
  -v ./ziti-id.json:/etc/ziti/identity.json \
  openziti/ziti-tunnel run /etc/ziti/identity.json
```

### Configuración del Dark Service

```bash
# Autenticarse al controlador
ziti edge login https://localhost:8441 \
  -u admin -p <password> \
  --ca /path/to/ca.cert

# Crear el servicio oscurecido (sin IP pública, sin DNS público)
ziti edge create service crapi-service \
  --role-attributes crapi

# Crear configuración de bind (el servidor)
ziti edge create config crapi-bind-config ziti-tunneler-client.v1 \
  '{"hostname":"localhost","port":8888}'

# Crear configuración de intercept (el cliente)
ziti edge create config crapi-intercept-config intercept.v1 \
  '{"protocols":["tcp"],"addresses":["dark.crapi.hackgdl"],"portRanges":[{"low":80,"high":80}]}'

# Crear service policy para el servidor (bind)
ziti edge create service-policy crapi-bind-policy Bind \
  --service-roles '@crapi-service' \
  --identity-roles '@crapi-server'

# Crear service policy para clientes (dial)
ziti edge create service-policy crapi-dial-policy Dial \
  --service-roles '@crapi-service' \
  --identity-roles '@crapi-clients'

# Crear identidad del servidor (donde corre crAPI)
ziti edge create identity device crapi-server \
  --role-attributes crapi-server \
  -o crapi-server.jwt

# Crear identidad de cliente legítimo
ziti edge create identity device demo-client \
  --role-attributes crapi-clients \
  -o demo-client.jwt
```

### Para la demo

**Sin identidad ZT** (lo que ve el atacante):
```bash
nmap -sV dark.crapi.hackgdl  # → Nada
curl http://dark.crapi.hackgdl  # → Connection refused
```

**Con identidad ZT** (lo que ve el usuario legítimo):
```bash
# El tunnel intercepta dark.crapi.hackgdl y lo enruta via ZT
ziti-edge-tunnel run --identity demo-client.json &
curl http://dark.crapi.hackgdl/api/v2/user/dashboard  # → Funciona!
```

### Verificación pre-demo

```bash
# Desde máquina SIN identidad ZT:
ping dark.crapi.hackgdl           # FAIL: unknown host
nmap dark.crapi.hackgdl           # FAIL: host down
curl http://dark.crapi.hackgdl    # FAIL: connection refused

# Desde máquina CON identidad ZT activa:
curl http://dark.crapi.hackgdl/api/v2/user/login  # OK: 200
```
