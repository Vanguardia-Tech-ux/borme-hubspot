#!/bin/bash
# Ejecuta el monitor BORME desde cron o manualmente
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
source venv/bin/activate
python -m borme_monitor.main "$@"
