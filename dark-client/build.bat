@echo off
REM ============================================================
REM  Compila dark-client con Java 21 y Maven
REM ============================================================

set JAVA_HOME=C:\oracle\Java\jdk-21.0.6
set PATH=%JAVA_HOME%\bin;%PATH%

echo [*] Java version:
java -version
echo.

echo [*] Compilando dark-client...
mvn clean package -q

if %ERRORLEVEL% NEQ 0 (
    echo [X] Error en la compilacion. Revisa los mensajes arriba.
    exit /b 1
)

echo.
echo [OK] JAR generado: target\dark-client.jar
echo.
echo Para ejecutar:
echo   run.bat [ruta-identidad.json] [url]
echo.
echo Ejemplo con identidad por defecto:
echo   run.bat C:\rolando\nf\sw\myConsumer.json
