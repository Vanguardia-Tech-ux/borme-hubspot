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

:: --- 0. Desactivar alias falsos de Python ---
echo [0/5] Desactivando alias de Python de Microsoft Store...
del "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe" >nul 2>&1
del "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe" >nul 2>&1
echo    OK

:: --- 1. Buscar Python ---
echo.
echo [1/5] Buscando Python...

:: Intentar python en PATH
set PYTHON_CMD=
where python >nul 2>&1
if not errorlevel 1 (
    set PYTHON_CMD=python
    goto python_encontrado
)

:: Buscar en rutas tipicas de instalacion
if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    goto python_encontrado
)
if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
    goto python_encontrado
)
if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    goto python_encontrado
)
if exist "C:\Python312\python.exe" (
    set "PYTHON_CMD=C:\Python312\python.exe"
    goto python_encontrado
)
if exist "C:\Python3\python.exe" (
    set "PYTHON_CMD=C:\Python3\python.exe"
    goto python_encontrado
)

:: No encontrado, instalar
echo    Python no encontrado. Instalando...
echo    Descargando Python 3.12...
powershell -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe' -OutFile '%TEMP%\python_setup.exe'"
if not exist "%TEMP%\python_setup.exe" (
    echo    ERROR: No se pudo descargar Python. Comprueba la conexion a internet.
    pause
    exit /b 1
)
echo    Instalando Python (puede tardar un par de minutos)...
start /wait "" "%TEMP%\python_setup.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
del "%TEMP%\python_setup.exe" >nul 2>&1

:: Buscar donde se instalo
if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    goto python_encontrado
)

echo    ERROR: Python se instalo pero no se encuentra.
echo    Cierra esta ventana, reinicia el ordenador e intenta de nuevo.
pause
exit /b 1

:python_encontrado
echo    OK: %PYTHON_CMD%

:: --- 2. Crear entorno virtual ---
echo.
echo [2/5] Creando entorno virtual...
if not exist "venv" (
    "%PYTHON_CMD%" -m venv venv
    echo    OK
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

:: --- 4. Credenciales ---
if not exist "logs" mkdir logs
if not exist "data" mkdir data

echo.
echo [4/5] Configurando credenciales...
powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('IyBCT1JNRSBNb25pdG9yIFZhbmd1YXJkaWEudGVjaApIU19QQVQ9cGF0LWV1MS1hZTRjM2M3My00ZjU1LTQ1M2QtOGNlOC02NjhlY2M3YWMwYzIKR01BSUxfVVNFUj1qZmFndWlsYUBnbWFpbC5jb20KR01BSUxfUEFTUz10bGZvIGtncG4gaWJ5eCBhd2ZoCkFMRVJUX0VNQUlMPWpmYWd1aWxhQGdtYWlsLmNvbQpNQVRDSF9USFJFU0hPTEQ9MC45MA==')) | Set-Content -Path '.env' -NoNewline"
echo    OK

:: --- 5. Tarea programada ---
echo.
echo [5/5] Configurando ejecucion diaria...
schtasks /create /tn "BORME_Monitor_Vanguardia" /tr "cmd /c \"%~dp0run.bat\"" /sc weekly /d MON,TUE,WED,THU,FRI /st 09:00 /f >nul 2>&1
if errorlevel 1 (
    echo    AVISO: Para la tarea programada, ejecuta como Administrador.
) else (
    echo    OK: Tarea programada creada L-V a las 09:00
)

echo.
echo ========================================================
echo     INSTALACION COMPLETADA
echo ========================================================
echo.
echo   Se ejecutara automaticamente L-V a las 09:00.
echo.
echo   Uso manual:
echo     run.bat              - Ejecutar hoy
echo     run.bat --test       - Modo test
echo     run.bat --fecha X    - Fecha concreta
echo.
pause
