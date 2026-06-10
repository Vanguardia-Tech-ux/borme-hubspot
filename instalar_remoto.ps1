$ProgressPreference = 'SilentlyContinue'

Write-Host "Desactivando alias de Python..." -ForegroundColor Yellow
Remove-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\python3.exe" -Force -ErrorAction SilentlyContinue

Write-Host "Eliminando instalacion anterior..." -ForegroundColor Yellow
Remove-Item -Recurse -Force "$env:USERPROFILE\borme-hubspot" -ErrorAction SilentlyContinue

Write-Host "Descargando programa..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://github.com/Vanguardia-Tech-ux/borme-hubspot/archive/refs/heads/main.zip" -OutFile "$env:TEMP\borme.zip"

Write-Host "Descomprimiendo..." -ForegroundColor Yellow
Expand-Archive -Path "$env:TEMP\borme.zip" -DestinationPath "$env:USERPROFILE" -Force
Rename-Item "$env:USERPROFILE\borme-hubspot-main" "borme-hubspot"

Write-Host "Lanzando instalador..." -ForegroundColor Green
Start-Process -Verb RunAs "$env:USERPROFILE\borme-hubspot\instalar.bat"
