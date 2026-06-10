"""Orquestador principal: descarga BORME → cruza con HubSpot → actualiza."""

import logging
import smtplib
import sys
from datetime import date, datetime
from email.mime.text import MIMEText
from pathlib import Path

from .config import GMAIL_USER, GMAIL_PASS, ALERT_EMAIL, LOGS_DIR
from .borme_client import obtener_actos_dia, ultima_fecha_laborable, ACTOS_RIESGO
from .hubspot_client import (
    ensure_properties,
    obtener_todas_empresas,
    crear_nota,
    actualizar_propiedades_borme,
)
from .matcher import cruzar_borme_hubspot


def configurar_logging(fecha: date):
    """Configura logging a archivo y consola."""
    log_file = LOGS_DIR / f"borme_{fecha.isoformat()}.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(log_file, encoding="utf-8"),
            logging.StreamHandler(),
        ],
        force=True,
    )
    return logging.getLogger(__name__)


def formatear_nota_borme(acto: dict) -> tuple[str, str]:
    """Genera título y cuerpo HTML para la nota en HubSpot."""
    titulo = f"BORME {acto['fecha']} — {acto['provincia']}"
    lineas = [
        f"<b>Empresa BORME:</b> {acto['nombre']}",
        f"<b>Provincia:</b> {acto['provincia']}",
        f"<b>Actos:</b> {', '.join(acto.get('actos', ['Sin clasificar']))}",
        f"<b>Detalle:</b> {acto['actos_raw']}",
    ]
    if acto.get("num_registro"):
        lineas.insert(0, f"<b>Nº registro:</b> {acto['num_registro']}")

    cuerpo = "<br>".join(lineas)
    return titulo, cuerpo


def generar_resumen_email(matches: list[dict], fecha: date) -> str:
    """Genera el cuerpo del email de resumen."""
    if not matches:
        return f"No se encontraron coincidencias en el BORME del {fecha.isoformat()}."

    riesgos = [m for m in matches if m["es_riesgo"]]
    cambios = [m for m in matches if not m["es_riesgo"]]

    lineas = [f"Resumen BORME {fecha.isoformat()}", f"Coincidencias encontradas: {len(matches)}", ""]

    if riesgos:
        lineas.append("⚠️  ALERTAS DE RIESGO:")
        for m in riesgos:
            emp_hs = m["empresa_hs"]["properties"]["name"]
            actos = ", ".join(m["acto_borme"].get("actos", []))
            lineas.append(f"  - {emp_hs} → {actos} (similitud: {m['similitud']:.0%})")
        lineas.append("")

    if cambios:
        lineas.append("📋 CAMBIOS DETECTADOS:")
        for m in cambios:
            emp_hs = m["empresa_hs"]["properties"]["name"]
            actos = ", ".join(m["acto_borme"].get("actos", []))
            lineas.append(f"  - {emp_hs} → {actos} (similitud: {m['similitud']:.0%})")

    return "\n".join(lineas)


def enviar_email(asunto: str, cuerpo: str):
    """Envía email de notificación vía Gmail SMTP."""
    if not GMAIL_USER or not GMAIL_PASS or not ALERT_EMAIL:
        logging.getLogger(__name__).warning("Email no configurado, saltando envío")
        return

    msg = MIMEText(cuerpo, "plain", "utf-8")
    msg["Subject"] = asunto
    msg["From"] = GMAIL_USER
    msg["To"] = ALERT_EMAIL

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=15) as server:
            server.login(GMAIL_USER, GMAIL_PASS)
            server.sendmail(GMAIL_USER, [ALERT_EMAIL], msg.as_string())
        logging.getLogger(__name__).info("Email enviado a %s", ALERT_EMAIL)
    except Exception as e:
        logging.getLogger(__name__).error("Error enviando email: %s", e)


def ejecutar(fecha: date | None = None, solo_test: bool = False):
    """Ejecuta el flujo completo."""
    if fecha is None:
        fecha = ultima_fecha_laborable()

    logger = configurar_logging(fecha)
    logger.info("=" * 60)
    logger.info("BORME Monitor — Ejecución %s", datetime.now().isoformat())
    logger.info("Procesando BORME del %s", fecha.isoformat())
    logger.info("=" * 60)

    # 1. Descargar y parsear BORME
    logger.info("Paso 1: Descargando BORME...")
    actos = obtener_actos_dia(fecha)
    if not actos:
        logger.info("No hay actos para procesar. Fin.")
        return

    logger.info("Total actos encontrados en BORME: %d", len(actos))

    # 2. Obtener empresas de HubSpot
    logger.info("Paso 2: Obteniendo empresas de HubSpot...")
    empresas_hs = obtener_todas_empresas()
    if not empresas_hs:
        logger.warning("No hay empresas en HubSpot. Fin.")
        return

    # 3. Cruzar
    logger.info("Paso 3: Cruzando BORME con HubSpot...")
    matches = cruzar_borme_hubspot(actos, empresas_hs)

    if not matches:
        logger.info("No se encontraron coincidencias.")
        resumen = generar_resumen_email(matches, fecha)
        enviar_email(f"BORME {fecha.isoformat()} — Sin coincidencias", resumen)
        return

    # 4. Actualizar HubSpot
    if not solo_test:
        logger.info("Paso 4: Asegurando propiedades custom en HubSpot...")
        ensure_properties()

        logger.info("Paso 5: Actualizando HubSpot...")
        for match in matches:
            emp = match["empresa_hs"]
            acto = match["acto_borme"]
            company_id = emp["id"]
            emp_nombre = emp["properties"]["name"]

            # Crear nota
            titulo, cuerpo = formatear_nota_borme(acto)
            if crear_nota(company_id, titulo, cuerpo):
                logger.info("  Nota creada para %s", emp_nombre)

            # Actualizar propiedades
            if actualizar_propiedades_borme(company_id, acto.get("actos", []), fecha, match["es_riesgo"]):
                logger.info("  Propiedades actualizadas para %s", emp_nombre)
    else:
        logger.info("MODO TEST — No se actualiza HubSpot")
        for match in matches:
            emp_nombre = match["empresa_hs"]["properties"]["name"]
            actos_str = ", ".join(match["acto_borme"].get("actos", []))
            logger.info("  MATCH: %s → %s (%.0f%%, %s)",
                        emp_nombre, actos_str, match["similitud"] * 100, match["match_tipo"])

    # 5. Email resumen
    logger.info("Paso 6: Enviando resumen por email...")
    resumen = generar_resumen_email(matches, fecha)
    asunto = f"BORME {fecha.isoformat()} — {len(matches)} coincidencias"
    enviar_email(asunto, resumen)

    logger.info("Ejecución completada. %d coincidencias procesadas.", len(matches))


def main():
    """Entry point para CLI."""
    import argparse
    parser = argparse.ArgumentParser(description="Monitor BORME → HubSpot")
    parser.add_argument("--fecha", type=str, help="Fecha a procesar (YYYY-MM-DD). Por defecto: último día laborable")
    parser.add_argument("--test", action="store_true", help="Modo test: no actualiza HubSpot")
    args = parser.parse_args()

    fecha = date.fromisoformat(args.fecha) if args.fecha else None
    ejecutar(fecha=fecha, solo_test=args.test)


if __name__ == "__main__":
    main()
