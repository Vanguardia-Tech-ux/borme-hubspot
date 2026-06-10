@echo off
chcp 65001 >nul
title BORME Monitor - Instalador
cls

echo ╔══════════════════════════════════════════════════╗
echo ║     BORME Monitor → HubSpot — Instalador        ║
echo ║     Vanguardia.tech                              ║
echo ╚══════════════════════════════════════════════════╝
echo.

cd /d "%~dp0"

:: --- 1. Verificar Python 3 ---
echo [1/6] Verificando Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo    ERROR: Python 3 no encontrado.
    echo    Descargalo desde https://www.python.org/downloads/
    echo    IMPORTANTE: Marca "Add Python to PATH" al instalar.
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo    OK: %%i

:: --- 2. Crear entorno virtual ---
echo.
echo [2/6] Creando entorno virtual...
if not exist "venv" (
    python -m venv venv
    echo    OK: Entorno virtual creado
) else (
    echo    OK: Entorno virtual ya existe
)

:: --- 3. Instalar dependencias ---
echo.
echo [3/6] Instalando dependencias...
call venv\Scripts\activate.bat
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo    OK: Dependencias instaladas

:: --- 4. Crear directorios ---
if not exist "logs" mkdir logs
if not exist "data" mkdir data

:: --- 5. Configurar credenciales ---
echo.
if exist ".env" (
    echo [4/6] Archivo .env ya existe.
    set /p RECONFIG="   Quieres reconfigurar las credenciales? (s/N): "
    if /i not "%RECONFIG%"=="s" goto skip_env
)

echo.
echo [4/6] Configuracion de credenciales:
echo    (Pulsa Enter para dejar el valor por defecto)
echo.

set /p HS_PAT_INPUT="   Token HubSpot (HS_PAT): "
set /p GMAIL_USER_INPUT="   Email Gmail (GMAIL_USER) [jfaguila@gmail.com]: "
set /p GMAIL_PASS_INPUT="   App Password Gmail (GMAIL_PASS): "
set /p ALERT_EMAIL_INPUT="   Email alertas (ALERT_EMAIL) [jfaguila@gmail.com]: "
set /p THRESHOLD_INPUT="   Umbral matching 0.0-1.0 (MATCH_THRESHOLD) [0.90]: "

if "%GMAIL_USER_INPUT%"=="" set GMAIL_USER_INPUT=jfaguila@gmail.com
if "%ALERT_EMAIL_INPUT%"=="" set ALERT_EMAIL_INPUT=jfaguila@gmail.com
if "%THRESHOLD_INPUT%"=="" set THRESHOLD_INPUT=0.90

(
echo # BORME Monitor — Credenciales
echo HS_PAT=%HS_PAT_INPUT%
echo GMAIL_USER=%GMAIL_USER_INPUT%
echo GMAIL_PASS=%GMAIL_PASS_INPUT%
echo ALERT_EMAIL=%ALERT_EMAIL_INPUT%
echo MATCH_THRESHOLD=%THRESHOLD_INPUT%
) > .env

echo.
echo    OK: Credenciales guardadas en .env

:skip_env

:: --- 6. Test rapido ---
echo.
echo [5/6] Ejecutando test rapido (modo test, sin tocar HubSpot)...
echo.
call venv\Scripts\activate.bat
python -m borme_monitor.main --test

:: --- 7. Tarea programada ---
echo.
echo [6/6] Configuracion de ejecucion diaria:
echo    Se ejecutara de lunes a viernes a las 10:00
echo.
set /p TASK_SETUP="   Quieres activar la ejecucion diaria automatica? (s/N): "

if /i "%TASK_SETUP%"=="s" (
    schtasks /create /tn "BORME_Monitor" /tr "\"%~dp0run.bat\"" /sc weekly /d MON,TUE,WED,THU,FRI /st 10:00 /f >nul 2>&1
    if errorlevel 1 (
        echo    AVISO: No se pudo crear la tarea. Ejecuta este instalador como Administrador.
        echo    O creala manualmente: Programador de tareas ^> BORME_Monitor
    ) else (
        echo    OK: Tarea programada creada (L-V a las 10:00)
    )
) else (
    echo    Puedes configurarlo manualmente despues:
    echo    Programador de tareas ^> Crear tarea basica ^> BORME_Monitor
    echo    Ejecutar: %~dp0run.bat
)

:: --- Fin ---
echo.
echo ╔══════════════════════════════════════════════════╗
echo ║     OK: Instalacion completada                   ║
echo ╚══════════════════════════════════════════════════╝
echo.
echo   Uso manual:
echo     run.bat              - Ejecutar hoy
echo     run.bat --test       - Modo test (no toca HubSpot)
echo     run.bat --fecha X    - Fecha concreta (YYYY-MM-DD)
echo.
echo   Logs en: %~dp0logs\
echo.
pause
