@echo off
chcp 65001 >nul
title BORME Monitor - Instalador Automatico
cls

echo ╔══════════════════════════════════════════════════╗
echo ║     BORME Monitor → HubSpot — Instalador        ║
echo ║     Vanguardia.tech                              ║
echo ╚══════════════════════════════════════════════════╝
echo.

cd /d "%~dp0"

:: --- 1. Verificar/Instalar Python 3 ---
echo [1/5] Verificando Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo    Python no encontrado. Instalando automaticamente...
    echo.
    winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo    No se pudo instalar con winget. Descargando instalador...
        echo.
        curl -L -o "%TEMP%\python_installer.exe" "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
        "%TEMP%\python_installer.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
        del "%TEMP%\python_installer.exe"
    )
    echo.
    echo    Python instalado. Reiniciando instalador para cargar PATH...
    echo.
    start "" "%~f0"
    exit /b 0
)
for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo    OK: %%i

:: --- 2. Crear entorno virtual ---
echo.
echo [2/5] Creando entorno virtual...
if not exist "venv" (
    python -m venv venv
    echo    OK: Entorno virtual creado
) else (
    echo    OK: Ya existe
)

:: --- 3. Instalar dependencias ---
echo.
echo [3/5] Instalando dependencias...
call venv\Scripts\activate.bat
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo    OK: Dependencias instaladas

:: --- 4. Crear directorios y credenciales ---
if not exist "logs" mkdir logs
if not exist "data" mkdir data

echo.
echo [4/5] Configurando credenciales...
(
echo # BORME Monitor — Credenciales Vanguardia.tech
echo HS_PAT=pat-eu1-ae4c3c73-4f55-453d-8ce8-668ecc7ac0c2
echo GMAIL_USER=jfaguila@gmail.com
echo GMAIL_PASS=tlfo kgpn ibyx awfh
echo ALERT_EMAIL=jfaguila@gmail.com
echo MATCH_THRESHOLD=0.90
) > .env
echo    OK: Credenciales configuradas

:: --- 5. Crear tarea programada (L-V 10:00) ---
echo.
echo [5/5] Configurando ejecucion diaria automatica...
schtasks /create /tn "BORME_Monitor_Vanguardia" /tr "\"%~dp0run.bat\"" /sc weekly /d MON,TUE,WED,THU,FRI /st 10:00 /f >nul 2>&1
if errorlevel 1 (
    echo    AVISO: Necesitas ejecutar como Administrador para la tarea programada.
    echo    Click derecho en instalar.bat ^> Ejecutar como administrador
    echo    O creala manualmente en el Programador de tareas.
) else (
    echo    OK: Tarea programada creada (L-V a las 10:00^)
)

:: --- Fin ---
echo.
echo ╔══════════════════════════════════════════════════╗
echo ║     INSTALACION COMPLETADA                       ║
echo ╚══════════════════════════════════════════════════╝
echo.
echo   Todo listo. El monitor se ejecutara automaticamente
echo   de lunes a viernes a las 10:00.
echo.
echo   Uso manual:
echo     run.bat              - Ejecutar hoy
echo     run.bat --test       - Modo test
echo     run.bat --fecha X    - Fecha concreta
echo.
pause
