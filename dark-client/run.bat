@echo off
REM ============================================================
REM  Ejecuta el Dark API Client
REM
REM  Modos:
REM    run.bat --attacker               → atacante sin identidad ZT (todo falla)
REM    run.bat <identidad> --list       → listar servicios accesibles
REM    run.bat <identidad> <servicio>   → cliente ZT autorizado (path default: /health)
REM    run.bat <identidad> <servicio> <path>
REM
REM  Ejemplo:
REM    run.bat C:\rolando\nf\sw\myConsumer.json --list
REM    run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark
REM    run.bat C:\rolando\nf\sw\myConsumer.json crapi-dark /health
REM ============================================================

set JAVA_HOME=C:\oracle\Java\jdk-21.0.6
set PATH=%JAVA_HOME%\bin;%PATH%

set IDENTITY=%1
set SERVICE=%2
set HTTPPATH=%3

REM Modo atacante: pasar solo el flag, sin argumentos extra
if "%IDENTITY%"=="--attacker" (
    java -jar target\dark-client.jar --attacker
    goto :end
)

if "%IDENTITY%"=="" set IDENTITY=C:\rolando\nf\sw\myConsumer.json
if "%SERVICE%"==""  set SERVICE=crapi-dark

if "%HTTPPATH%"=="" (
    java -jar target\dark-client.jar "%IDENTITY%" "%SERVICE%"
) else (
    java -jar target\dark-client.jar "%IDENTITY%" "%SERVICE%" "%HTTPPATH%"
)

:end
