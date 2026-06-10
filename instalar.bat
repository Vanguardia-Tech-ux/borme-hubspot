@echo off
chcp 65001 >nul
title BORME Monitor - Instalador Automatico
cls

echo ========================================================
echo     BORME Monitor - HubSpot  --  Instalador
echo     Vanguardia.tech
echo ========================================================
echo.

cd /d "%~dp0"

:: --- 0. Desactivar alias falsos de Python (Microsoft Store) ---
echo [0/5] Desactivando alias de Python de Microsoft Store...
powershell -Command "if (Test-Path '%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe') { Remove-Item '%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe' -Force -ErrorAction SilentlyContinue }; if (Test-Path '%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe') { Remove-Item '%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe' -Force -ErrorAction SilentlyContinue }"
echo    OK: Alias desactivados

:: --- 1. Verificar/Instalar Python ---
echo.
echo [1/5] Verificando Python...

:: Buscar Python real (no el alias de Microsoft Store)
set PYTHON_FOUND=0
where python >nul 2>&1
if not errorlevel 1 (
    python --version >nul 2>&1
    if not errorlevel 1 set PYTHON_FOUND=1
)

if "%PYTHON_FOUND%"=="0" (
    echo    Python no encontrado. Instalando...
    echo.
    where winget >nul 2>&1
    if errorlevel 1 (
        echo    Descargando Python 3.12...
        powershell -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe' -OutFile '%TEMP%\python_setup.exe'"
        echo    Instalando Python (puede tardar un minuto)...
        start /wait "" "%TEMP%\python_setup.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
        del "%TEMP%\python_setup.exe" 2>nul
    ) else (
        winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements
    )
    echo.
    echo    Python instalado. Reiniciando instalador para cargar PATH...
    echo.
    timeout /t 3 >nul
    start "" cmd /c "%~f0"
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
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r requirements.txt
echo    OK: Dependencias instaladas

:: --- 4. Crear directorios y credenciales ---
if not exist "logs" mkdir logs
if not exist "data" mkdir data

echo.
echo [4/5] Configurando credenciales...
powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('IyBCT1JNRSBNb25pdG9yIFZhbmd1YXJkaWEudGVjaApIU19QQVQ9cGF0LWV1MS1hZTRjM2M3My00ZjU1LTQ1M2QtOGNlOC02NjhlY2M3YWMwYzIKR01BSUxfVVNFUj1qZmFndWlsYUBnbWFpbC5jb20KR01BSUxfUEFTUz10bGZvIGtncG4gaWJ5eCBhd2ZoCkFMRVJUX0VNQUlMPWpmYWd1aWxhQGdtYWlsLmNvbQpNQVRDSF9USFJFU0hPTEQ9MC45MA==')) | Set-Content -Path '.env' -NoNewline"
echo    OK: Credenciales configuradas

:: --- 5. Crear tarea programada (L-V 09:00) ---
echo.
echo [5/5] Configurando ejecucion diaria...
schtasks /create /tn "BORME_Monitor_Vanguardia" /tr "cmd /c \"%~dp0run.bat\"" /sc weekly /d MON,TUE,WED,THU,FRI /st 09:00 /f >nul 2>&1
if errorlevel 1 (
    echo    AVISO: Para la tarea programada, ejecuta como Administrador.
    echo    Click derecho en instalar.bat - Ejecutar como administrador
) else (
    echo    OK: Tarea programada creada L-V a las 09:00
)

:: --- Fin ---
echo.
echo ========================================================
echo     INSTALACION COMPLETADA
echo ========================================================
echo.
echo   Todo listo. El monitor se ejecutara automaticamente
echo   de lunes a viernes a las 09:00.
echo.
echo   Uso manual:
echo     run.bat              - Ejecutar hoy
echo     run.bat --test       - Modo test
echo     run.bat --fecha X    - Fecha concreta
echo.
pause
