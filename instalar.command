#!/bin/bash
# ============================================================
# BORME Monitor — Instalador con un click (macOS)
# Doble click en este archivo para instalar
# ============================================================
set -e

clear
echo "╔══════════════════════════════════════════════════╗"
echo "║     BORME Monitor → HubSpot — Instalador        ║"
echo "║     Vanguardia.tech                              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# --- 1. Verificar Python 3 ---
echo "🔍 Verificando Python..."
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version 2>&1)
    echo "   ✅ $PY_VERSION"
else
    echo "   ❌ Python 3 no encontrado."
    echo "   Instálalo desde https://www.python.org/downloads/"
    echo ""
    read -p "Pulsa Enter para salir..."
    exit 1
fi

# --- 2. Crear entorno virtual ---
echo ""
echo "📦 Creando entorno virtual..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "   ✅ Entorno virtual creado"
else
    echo "   ✅ Entorno virtual ya existe"
fi

# --- 3. Instalar dependencias ---
echo ""
echo "📥 Instalando dependencias..."
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo "   ✅ Dependencias instaladas"

# --- 4. Crear directorios ---
mkdir -p logs data

# --- 5. Configurar credenciales ---
echo ""
if [ -f ".env" ]; then
    echo "⚙️  Archivo .env ya existe."
    read -p "   ¿Quieres reconfigurar las credenciales? (s/N): " RECONFIG
    if [[ "$RECONFIG" != "s" && "$RECONFIG" != "S" ]]; then
        SKIP_ENV=true
    fi
fi

if [ "$SKIP_ENV" != "true" ]; then
    echo ""
    echo "⚙️  Configuración de credenciales:"
    echo "   (Pulsa Enter para dejar el valor por defecto)"
    echo ""

    read -p "   Token HubSpot (HS_PAT): " HS_PAT_INPUT
    read -p "   Email Gmail (GMAIL_USER) [jfaguila@gmail.com]: " GMAIL_USER_INPUT
    read -p "   App Password Gmail (GMAIL_PASS): " GMAIL_PASS_INPUT
    read -p "   Email alertas (ALERT_EMAIL) [jfaguila@gmail.com]: " ALERT_EMAIL_INPUT
    read -p "   Umbral matching 0.0-1.0 (MATCH_THRESHOLD) [0.90]: " THRESHOLD_INPUT

    GMAIL_USER_INPUT=${GMAIL_USER_INPUT:-jfaguila@gmail.com}
    ALERT_EMAIL_INPUT=${ALERT_EMAIL_INPUT:-jfaguila@gmail.com}
    THRESHOLD_INPUT=${THRESHOLD_INPUT:-0.90}

    cat > .env <<ENVEOF
# BORME Monitor — Credenciales
HS_PAT=${HS_PAT_INPUT}
GMAIL_USER=${GMAIL_USER_INPUT}
GMAIL_PASS=${GMAIL_PASS_INPUT}
ALERT_EMAIL=${ALERT_EMAIL_INPUT}
MATCH_THRESHOLD=${THRESHOLD_INPUT}
ENVEOF

    echo ""
    echo "   ✅ Credenciales guardadas en .env"
fi

# --- 6. Dar permisos ---
chmod +x run.sh

# --- 7. Test rápido ---
echo ""
echo "🧪 Ejecutando test rápido (modo test, sin tocar HubSpot)..."
echo ""
source venv/bin/activate
python -m borme_monitor.main --test 2>&1 | tail -5
echo ""

# --- 8. Configurar cron ---
echo "⏰ Configuración de ejecución diaria (cron):"
echo "   Se ejecutará de lunes a viernes a las 10:00"
echo ""
read -p "   ¿Quieres activar la ejecución diaria automática? (s/N): " CRON_SETUP

if [[ "$CRON_SETUP" == "s" || "$CRON_SETUP" == "S" ]]; then
    CRON_LINE="0 10 * * 1-5 $DIR/run.sh >> $DIR/logs/cron.log 2>&1"

    # Evitar duplicados
    (crontab -l 2>/dev/null | grep -v "borme-hubspot/run.sh"; echo "$CRON_LINE") | crontab -
    echo "   ✅ Cron configurado: L-V a las 10:00"
    echo "   Línea: $CRON_LINE"
else
    echo "   Puedes configurarlo manualmente después:"
    echo "   crontab -e"
    echo "   0 10 * * 1-5 $DIR/run.sh"
fi

# --- Fin ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     ✅ Instalación completada                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Uso manual:"
echo "    ./run.sh              → Ejecutar hoy"
echo "    ./run.sh --test       → Modo test (no toca HubSpot)"
echo "    ./run.sh --fecha X    → Fecha concreta (YYYY-MM-DD)"
echo ""
echo "  Logs en: $DIR/logs/"
echo ""
read -p "Pulsa Enter para cerrar..."
