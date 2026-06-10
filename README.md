# BORME Monitor → HubSpot

Monitoriza el Boletín Oficial del Registro Mercantil (BORME) diariamente y actualiza las empresas que ya existen en HubSpot CRM con los actos mercantiles detectados.

## Qué hace

1. Descarga el sumario BORME del día (API datos abiertos del BOE)
2. Parsea los XMLs de la Sección A (actos inscritos) de todas las provincias
3. Cruza las empresas del BORME con las que tienes en HubSpot (por CIF y nombre)
4. Para cada coincidencia:
   - Crea una nota en la ficha de empresa con los actos detectados
   - Actualiza propiedades: `ultimo_acto_borme`, `fecha_ultimo_borme`, `alerta_borme`
5. Envía un email resumen con las coincidencias

## Actos que detecta

Nombramientos, ceses, constituciones, disoluciones, cambios de domicilio, ampliaciones de capital, concursos de acreedores, modificaciones estatutarias, y más.

## Instalación

```bash
git clone <este-repo>
cd borme-hubspot
bash setup.sh
```

Edita `.env` con tus credenciales:
- `HS_PAT` — Token de acceso de HubSpot (PAT)
- `GMAIL_USER` / `GMAIL_PASS` — Para envío de emails de resumen
- `ALERT_EMAIL` — Destinatario de los emails

## Uso

```bash
# Ejecutar con fecha de hoy (último día laborable)
./run.sh

# Ejecutar para una fecha concreta
./run.sh --fecha 2026-06-09

# Modo test (no modifica HubSpot)
./run.sh --test

# Modo test con fecha concreta
./run.sh --test --fecha 2026-06-09
```

## Cron (ejecución diaria automática)

```bash
crontab -e
# Añadir:
0 10 * * 1-5 /ruta/completa/borme-hubspot/run.sh
```

Se ejecuta a las 10:00 de lunes a viernes.

## Estructura

```
borme_monitor/
  config.py          — Configuración desde .env
  borme_client.py    — Descarga y parseo del BORME (API + XML)
  hubspot_client.py  — Operaciones con HubSpot CRM
  matcher.py         — Cruce BORME ↔ HubSpot (CIF + fuzzy matching)
  main.py            — Orquestador principal
```

## Logs

Los logs se guardan en `logs/borme_YYYY-MM-DD.log`.
