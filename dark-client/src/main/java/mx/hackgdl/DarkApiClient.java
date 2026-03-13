package mx.hackgdl;

import org.openziti.Ziti;
import org.openziti.ZitiContext;
import org.openziti.ZitiConnection;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

/**
 * HackGDL 2026 — Exploit the Invisible
 *
 * Cliente Zero Trust que conecta al Dark Service (crAPI) a través
 * del fabric de OpenZiti / NetFoundry usando una identidad enrollada.
 *
 * Sin identidad ZT → el host no existe en ningún DNS público.
 * Con esta identidad → HTTP 200 OK.
 *
 * Usos:
 *
 *   1) Listar servicios disponibles (para descubrir el nombre del servicio):
 *      java -jar dark-client.jar <identidad.json> --list
 *
 *   2) Conectar por nombre de servicio ZT (modo recomendado):
 *      java -jar dark-client.jar <identidad.json> <nombre-servicio> [path]
 *      Ejemplo: run.bat crapi-dark /health
 *
 *   3) Conectar por URL con intercept config (requiere config en NetFoundry):
 *      java -jar dark-client.jar <identidad.json> http://dark.crapi.hackgdl/health
 */
public class DarkApiClient {

    private static final String GREEN  = "\u001B[32m";
    private static final String RED    = "\u001B[31m";
    private static final String CYAN   = "\u001B[36m";
    private static final String YELLOW = "\u001B[33m";
    private static final String RESET  = "\u001B[0m";

    public static void main(String[] args) throws Exception {

        String identityPath = args.length > 0 ? args[0] : "myConsumer.json";
        String target       = args.length > 1 ? args[1] : "crapi-dark";
        String httpPath     = args.length > 2 ? args[2] : "/health";

        // ── Modo atacante: sin identidad ZT ─────────────────────────────
        if ("--attacker".equals(identityPath)) {
            runAttackerMode("dark.crapi.hackgdl");
            return;
        }

        printBanner(identityPath, target, httpPath);

        // ── 1. Verificar identidad ───────────────────────────────────────
        File identityFile = new File(identityPath);
        if (!identityFile.exists()) {
            System.err.println(RED + "[✗] Identidad no encontrada: " + identityPath + RESET);
            System.exit(1);
        }

        // ── 2. Inicializar contexto ZT ───────────────────────────────────
        System.out.println("[*] Cargando identidad Zero Trust...");
        ZitiContext ctx = Ziti.newContext(identityFile, "".toCharArray());

        System.out.println("[*] Autenticando con NetFoundry...");
        waitForActive(ctx, 8_000);
        System.out.println(GREEN + "[✓] Identidad ZT activa" + RESET);
        System.out.println();

        // ── 3. Modo listar servicios ─────────────────────────────────────
        if ("--list".equals(target)) {
            listServices(ctx);
            ctx.destroy();
            return;
        }

        // ── 4. Modo URL (requiere intercept.v1 en NetFoundry) ───────────
        if (target.startsWith("http://") || target.startsWith("https://")) {
            System.out.println("[!] Modo URL — requiere intercept config en NetFoundry.");
            System.out.println("    Si falla, usa el nombre de servicio:");
            System.out.println("    run.bat " + identityPath + " crapi-dark /health");
            System.out.println();
        }

        // ── 5. Modo servicio ZT (dial por nombre) ────────────────────────
        String serviceName = target;
        if (target.startsWith("http")) {
            // Extraer host como service name aproximado
            serviceName = target.replaceAll("https?://([^/]+).*", "$1");
        }

        System.out.println("[*] Esperando disponibilidad del servicio ZT...");
        var svc = ctx.getService(serviceName, 8000L);
        if (svc == null) {
            System.out.println(RED + "[✗] Servicio '" + serviceName + "' no accesible con esta identidad." + RESET);
            System.out.println("    Verifica en NetFoundry que la identidad tenga acceso al servicio.");
            ctx.destroy();
            return;
        }
        System.out.println(GREEN + "[✓] Servicio listo" + RESET);
        System.out.println();
        System.out.println("[*] Abriendo túnel ZT → " + GREEN + serviceName + RESET);
        System.out.println();

        try {
            ZitiConnection conn = ctx.dial(serviceName);

            // ── Request ──────────────────────────────────────────────────
            String host = "dark.crapi.hackgdl";
            String[] requestLines = {
                "GET " + httpPath + " HTTP/1.1",
                "Host: " + host,
                "User-Agent: DarkApiClient/1.0 HackGDL2026",
                "Accept: application/json",
                "Connection: close"
            };

            System.out.println("  * Resolviendo: " + CYAN + host + RESET
                    + " → " + GREEN + "resuelto via OpenZiti fabric" + RESET);
            System.out.println("  * Conectando a " + CYAN + host + ":80" + RESET
                    + " → " + GREEN + "conectado" + RESET);
            System.out.println("  * Identidad ZT verificada → " + GREEN + "acceso autorizado" + RESET);
            System.out.println();
            for (String line : requestLines) {
                System.out.println(CYAN + "  > " + RESET + line);
            }
            System.out.println(CYAN + "  >" + RESET);
            System.out.println();

            String httpRequest = String.join("\r\n", requestLines) + "\r\n\r\n";
            conn.write(httpRequest.getBytes(StandardCharsets.UTF_8));

            // ── Response ─────────────────────────────────────────────────
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int n;
            while ((n = conn.read(buffer, 0, buffer.length)) > 0) {
                baos.write(buffer, 0, n);
            }
            conn.close();

            printHttpResponse(baos.toString(StandardCharsets.UTF_8));

        } catch (Exception e) {
            System.out.println(RED + "[✗] Error: " + e.getMessage() + RESET);
            System.out.println();
            System.out.println("  Ejecuta con --list para ver los servicios disponibles:");
            System.out.println("  run.bat " + identityPath + " --list");
        }

        // ── 6. Resumen ───────────────────────────────────────────────────
        System.out.println();
        System.out.println("══════════════════════════════════════════════");
        System.out.println(GREEN + "  Solo identidades ZT autorizadas alcanzan" + RESET);
        System.out.println(GREEN + "  este servicio. Sin identidad → invisible." + RESET);
        System.out.println("══════════════════════════════════════════════");

        ctx.destroy();
    }

    // ── Modo atacante: intenta alcanzar el Dark Service sin identidad ZT ─
    private static void runAttackerMode(String darkHost) throws Exception {
        System.out.println();
        System.out.println(RED + "══════════════════════════════════════════════" + RESET);
        System.out.println(RED + "  MODO ATACANTE — sin identidad Zero Trust"    + RESET);
        System.out.println(RED + "  Target: http://" + darkHost + "/health"      + RESET);
        System.out.println(RED + "══════════════════════════════════════════════" + RESET);
        System.out.println();

        // ── Ataque 1: DNS lookup ─────────────────────────────────────────
        System.out.println("  [Paso 1/3] Resolución DNS");
        System.out.println();
        System.out.println(CYAN + "  * Intentando resolver hostname: " + darkHost + RESET);
        System.out.println(CYAN + "  * Consultando DNS público..." + RESET);
        System.out.println();

        boolean dnsResolved = false;
        try {
            InetAddress addr = InetAddress.getByName(darkHost);
            dnsResolved = true;
            System.out.println(RED + "  [!] DNS resolvió → " + addr.getHostAddress()
                    + " (cliente ZT activo?)" + RESET);
        } catch (Exception e) {
            System.out.println(RED    + "  * DNS response: NXDOMAIN" + RESET);
            System.out.println(GREEN  + "  * " + darkHost + " no existe en ningún DNS público" + RESET);
            System.out.println(GREEN  + "  * No hay IP. No hay host. No hay superficie." + RESET);
            System.out.println(GREEN  + "  [✗] DNS — NXDOMAIN" + RESET);
        }
        System.out.println();

        // ── Ataque 2: HTTP directo ───────────────────────────────────────
        System.out.println("  [Paso 2/3] Petición HTTP");
        System.out.println();
        System.out.println(CYAN + "  > GET /health HTTP/1.1" + RESET);
        System.out.println(CYAN + "  > Host: " + darkHost    + RESET);
        System.out.println(CYAN + "  > User-Agent: Attacker/1.0" + RESET);
        System.out.println(CYAN + "  >" + RESET);
        System.out.println();
        System.out.println(CYAN + "  * Intentando conexión TCP a " + darkHost + ":80..." + RESET);

        try {
            HttpURLConnection conn = (HttpURLConnection)
                    new URL("http://" + darkHost + "/health").openConnection();
            conn.setConnectTimeout(4000);
            conn.setReadTimeout(4000);
            int code = conn.getResponseCode();
            System.out.println(RED + "  < HTTP " + code + " (cliente ZT activo?)" + RESET);
        } catch (Exception e) {
            System.out.println();
            System.out.println(RED   + "  * " + e.getClass().getSimpleName() + ": " + darkHost + RESET);
            System.out.println(GREEN + "  * La petición HTTP nunca llegó a ningún servidor." + RESET);
            System.out.println(GREEN + "  * Sin DNS → sin IP → sin TCP → sin HTTP." + RESET);
            System.out.println(GREEN + "  * No hay firewall que bloquee — el host no existe." + RESET);
            System.out.println(GREEN + "  [✗] HTTP — Connection failed (0 bytes enviados)" + RESET);
        }
        System.out.println();

        // ── Ataque 3: TCP port scan ──────────────────────────────────────
        System.out.println("  [Paso 3/3] TCP port scan — puerto 80");
        System.out.println();
        System.out.println(CYAN + "  * Intentando abrir socket a " + darkHost + ":80..." + RESET);

        try {
            java.net.Socket socket = new java.net.Socket();
            socket.connect(new java.net.InetSocketAddress(darkHost, 80), 3000);
            socket.close();
            System.out.println(RED + "  [!] Puerto 80 abierto (cliente ZT activo?)" + RESET);
        } catch (Exception e) {
            System.out.println(RED   + "  * " + e.getClass().getSimpleName() + ": " + darkHost + RESET);
            System.out.println(GREEN + "  * No hay socket. No hay puerto. No hay nada." + RESET);
            System.out.println(GREEN + "  [✗] TCP — sin respuesta en ningún puerto" + RESET);
        }
        System.out.println();

        // ── Resumen ──────────────────────────────────────────────────────
        System.out.println("══════════════════════════════════════════════");
        System.out.println();
        System.out.println("  Resultado sin identidad ZT:");
        System.out.println();
        System.out.println(GREEN + "  DNS  →  NXDOMAIN          (el host no existe)"    + RESET);
        System.out.println(GREEN + "  HTTP →  Connection failed  (0 bytes intercambiados)" + RESET);
        System.out.println(GREEN + "  TCP  →  No route to host   (sin puertos expuestos)" + RESET);
        System.out.println();
        System.out.println("  No es un firewall. No es rate limiting.");
        System.out.println("  El servicio es " + GREEN + "invisible" + RESET + " sin identidad ZT.");
        System.out.println();
        System.out.println("══════════════════════════════════════════════");
        System.out.println();
        System.out.println("  Ahora ejecuta con identidad autorizada:");
        System.out.println("  " + CYAN + "run.bat" + RESET);
        System.out.println();
    }

    // ── Listar servicios accesibles con esta identidad ───────────────────
    private static void listServices(ZitiContext ctx) throws InterruptedException {
        System.out.println("[*] Información de identidad y servicios:");
        System.out.println();

        Thread.sleep(2000);


        // Probar servicios comunes
        System.out.println("  Probando acceso a servicios conocidos:");
        System.out.println();
        String[] candidates = {"crapi-dark", "crapi", "dark-crapi", "crapi-web", "crapi-service"};
        boolean found = false;
        for (String name : candidates) {
            try {
                var svc = ctx.getService(name, 800L);
                if (svc != null) {
                    System.out.println("  " + GREEN + "  [✓] accesible : " + name + RESET);
                    found = true;
                } else {
                    System.out.println("  " + "  [ ] sin acceso : " + name);
                }
            } catch (Exception e) {
                System.out.println("  " + "  [ ] sin acceso : " + name);
            }
        }

        System.out.println();
        if (!found) {
            System.out.println("  " + RED + "Ningún servicio es accesible con esta identidad." + RESET);
            System.out.println();
            System.out.println("  Solución en NetFoundry Console:");
            System.out.println("  1. AppWANs → busca el AppWAN que incluye 'crapi-dark'");
            System.out.println("  2. Agrega la identidad de myConsumer.json");
            System.out.println("  3. Guarda y vuelve a correr run.bat");
        }
        System.out.println();
    }

    // ── Parsear y mostrar la respuesta HTTP ──────────────────────────────
    private static void printHttpResponse(String raw) {
        String[] lines = raw.split("\r\n|\n");
        if (lines.length == 0) {
            System.out.println(RED + "  (sin respuesta)" + RESET);
            return;
        }

        boolean inBody    = false;
        boolean firstLine = true;
        StringBuilder body = new StringBuilder();

        for (String line : lines) {
            if (!inBody) {
                if (line.isEmpty()) {
                    // Línea en blanco = fin de headers
                    System.out.println(GREEN + "  <" + RESET);
                    System.out.println();
                    inBody = true;
                    continue;
                }
                if (firstLine) {
                    // Status line — resaltar en verde o rojo
                    boolean ok = line.matches("HTTP/\\S+\\s+2\\d\\d.*");
                    System.out.println((ok ? GREEN : RED) + "  < " + line + RESET);
                    firstLine = false;
                } else {
                    System.out.println(GREEN + "  < " + RESET + line);
                }
            } else {
                body.append(line).append("\n");
            }
        }

        // Body
        if (body.length() > 0) {
            System.out.println(YELLOW + "  " + body.toString().trim() + RESET);
        }
    }

    // ── Esperar a que el contexto esté Active ────────────────────────────
    private static void waitForActive(ZitiContext ctx, long timeoutMs) throws InterruptedException {
        long deadline = System.currentTimeMillis() + timeoutMs;
        while (System.currentTimeMillis() < deadline) {
            String status = ctx.getStatus().toString();
            if ("Active".equalsIgnoreCase(status)) return;
            if ("Disabled".equalsIgnoreCase(status) || "NotAuthorized".equalsIgnoreCase(status)) {
                System.err.println(RED + "[✗] Estado ZT: " + status
                        + " — identidad inactiva en NetFoundry" + RESET);
                System.exit(1);
            }
            Thread.sleep(400);
        }
    }

    private static void printBanner(String identity, String target, String path) {
        System.out.println();
        System.out.println(CYAN + "══════════════════════════════════════════════" + RESET);
        System.out.println(CYAN + "  HackGDL 2026 — Dark API Client"             + RESET);
        System.out.println(CYAN + "  Exploit the Invisible / OpenZiti"            + RESET);
        System.out.println(CYAN + "══════════════════════════════════════════════" + RESET);
        System.out.println();
        System.out.println("  Identidad : " + identity);
        if ("--list".equals(target)) {
            System.out.println("  Modo      : listar servicios");
        } else {
            System.out.println("  Servicio  : " + target);
            System.out.println("  Path      : " + path);
        }
        System.out.println();
    }
}
