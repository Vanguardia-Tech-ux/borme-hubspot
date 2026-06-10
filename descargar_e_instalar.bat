@echo off
chcp 65001 >nul
title BORME Monitor - Descarga e Instalacion
cls

echo ╔══════════════════════════════════════════════════╗
echo ║     BORME Monitor — Descarga e Instalacion       ║
echo ║     Vanguardia.tech                              ║
echo ╚══════════════════════════════════════════════════╝
echo.
echo Descargando desde GitHub...
echo.

set DESTINO=%USERPROFILE%\borme-hubspot
set ZIP=%TEMP%\borme-hubspot.zip

:: Descargar ZIP de GitHub
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/Vanguardia-Tech-ux/borme-hubspot/archive/refs/heads/main.zip' -OutFile '%ZIP%'"

if not exist "%ZIP%" (
    echo ERROR: No se pudo descargar. Comprueba la conexion a internet.
    pause
    exit /b 1
)

:: Descomprimir
echo Descomprimiendo...
if exist "%DESTINO%" rmdir /s /q "%DESTINO%"
powershell -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%TEMP%\borme-temp' -Force"
move "%TEMP%\borme-temp\borme-hubspot-main" "%DESTINO%" >nul
rmdir /s /q "%TEMP%\borme-temp" 2>nul
del "%ZIP%" 2>nul

echo OK: Descargado en %DESTINO%
echo.
echo Lanzando instalador...
echo.

cd /d "%DESTINO%"
call instalar.bat
