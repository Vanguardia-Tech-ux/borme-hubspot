$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  BORME Monitor - Descarga e Instalacion" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Desactivando alias de Python de Microsoft Store..." -ForegroundColor Yellow
Remove-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe" -Force 2>$null
Remove-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\python3.exe" -Force 2>$null
Write-Host "  OK" -ForegroundColor Green

Write-Host "[2/4] Eliminando instalacion anterior si existe..." -ForegroundColor Yellow
Remove-Item -Recurse -Force "$env:USERPROFILE\borme-hubspot" 2>$null
Remove-Item -Recurse -Force "$env:USERPROFILE\borme-hubspot-main" 2>$null
Remove-Item -Force "$env:TEMP\borme.zip" 2>$null
Write-Host "  OK" -ForegroundColor Green

Write-Host "[3/4] Descargando programa desde GitHub..." -ForegroundColor Yellow
$ErrorActionPreference = 'Stop'
try {
    Invoke-WebRequest -Uri "https://github.com/Vanguardia-Tech-ux/borme-hubspot/archive/refs/heads/main.zip" -OutFile "$env:TEMP\borme.zip"
    Write-Host "  OK" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: No se pudo descargar. Comprueba la conexion a internet." -ForegroundColor Red
    Read-Host "Pulsa Enter para salir"
    exit 1
}
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "[4/4] Descomprimiendo..." -ForegroundColor Yellow
Expand-Archive -Path "$env:TEMP\borme.zip" -DestinationPath "$env:USERPROFILE" -Force
Rename-Item "$env:USERPROFILE\borme-hubspot-main" "$env:USERPROFILE\borme-hubspot" -Force 2>$null
Remove-Item -Force "$env:TEMP\borme.zip" 2>$null
Write-Host "  OK: Instalado en $env:USERPROFILE\borme-hubspot" -ForegroundColor Green

Write-Host ""
Write-Host "Lanzando instalador..." -ForegroundColor Cyan
Write-Host ""

Start-Process -Verb RunAs -FilePath "cmd.exe" -ArgumentList "/c `"$env:USERPROFILE\borme-hubspot\instalar.bat`""
