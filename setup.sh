#!/bin/bash
# Instalación del monitor BORME-HubSpot
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=== Instalando BORME Monitor ==="

# Crear entorno virtual
if [ ! -d "venv" ]; then
    echo "Creando entorno virtual..."
    python3 -m venv venv
fi

echo "Instalando dependencias..."
source venv/bin/activate
pip install -r requirements.txt

# Copiar .env si no existe
if [ ! -f ".env" ]; then
    echo "Copiando .env.example → .env (editar con credenciales reales)"
    cp .env.example .env
fi

# Crear directorios
mkdir -p logs data

# Dar permisos de ejecución
chmod +x run.sh

echo ""
echo "=== Instalación completada ==="
echo ""
echo "Pasos siguientes:"
echo "  1. Edita .env con tus credenciales"
echo "  2. Prueba: ./run.sh --test"
echo "  3. Configura cron: crontab -e"
echo "     0 10 * * 1-5 $DIR/run.sh"
echo ""
