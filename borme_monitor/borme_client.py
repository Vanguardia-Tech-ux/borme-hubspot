"""Cliente para la API de datos abiertos del BORME (BOE)."""

import logging
import xml.etree.ElementTree as ET
from datetime import date, timedelta

import requests

from .config import BORME_API_BASE, DATA_DIR

logger = logging.getLogger(__name__)

HEADERS_JSON = {"Accept": "application/json"}


def get_sumario(fecha: date) -> dict | None:
    """Descarga el sumario del BORME para una fecha dada (JSON)."""
    url = f"{BORME_API_BASE}/{fecha.strftime('%Y%m%d')}"
    logger.info("Descargando sumario: %s", url)
    resp = requests.get(url, headers=HEADERS_JSON, timeout=30)
    if resp.status_code == 404:
        logger.warning("No hay BORME para %s (404)", fecha)
        return None
    resp.raise_for_status()
    data = resp.json()
    if data.get("status", {}).get("code") != "200":
        logger.warning("API devolvió estado no-200: %s", data.get("status"))
        return None
    return data


def extraer_urls_seccion_a(sumario: dict) -> list[dict]:
    """Extrae las URLs XML de la Sección A (actos inscritos) del sumario."""
    items = []
    for diario in sumario.get("data", {}).get("sumario", {}).get("diario", []):
        for seccion in diario.get("seccion", []):
            if seccion.get("codigo") != "A":
                continue
            for item in seccion.get("item", []):
                items.append({
                    "id": item["identificador"],
                    "provincia": item["titulo"],
                    "url_xml": item.get("url_xml", ""),
                    "url_pdf": item.get("url_pdf", {}).get("texto", ""),
                })
    return items


def descargar_xml_actos(url_xml: str) -> str | None:
    """Descarga el XML de actos de una provincia."""
    logger.debug("Descargando XML: %s", url_xml)
    resp = requests.get(url_xml, timeout=30)
    if resp.status_code != 200:
        logger.warning("Error descargando %s: %d", url_xml, resp.status_code)
        return None
    return resp.text


def parsear_xml_actos(xml_text: str) -> list[dict]:
    """Parsea el XML de una provincia y extrae empresas + actos.

    Cada entrada del BORME tiene:
    - <p class="articulo">NUMERO - NOMBRE EMPRESA.</p>
    - <p class="parrafo">Actos mercantiles. Datos registrales...</p>
    """
    root = ET.fromstring(xml_text)
    texto = root.find("texto")
    if texto is None:
        return []

    # Extraer metadatos
    meta = root.find("metadatos")
    provincia = meta.findtext("titulo", "") if meta is not None else ""
    fecha = meta.findtext("fecha_publicacion", "") if meta is not None else ""

    empresas = []
    current_empresa = None

    for p in texto.findall("p"):
        cls = p.get("class", "")
        text = (p.text or "").strip()

        if cls == "articulo":
            # Formato: "273961 - NOMBRE EMPRESA."
            parts = text.split(" - ", 1)
            nombre = parts[1].rstrip(".").strip() if len(parts) > 1 else text.rstrip(".").strip()
            num_registro = parts[0].strip() if len(parts) > 1 else ""
            current_empresa = {
                "nombre": nombre,
                "num_registro": num_registro,
                "provincia": provincia,
                "fecha": fecha,
                "actos_raw": "",
                "actos": [],
            }
            empresas.append(current_empresa)

        elif cls == "parrafo" and current_empresa is not None:
            current_empresa["actos_raw"] = text
            current_empresa["actos"] = _clasificar_actos(text)

    return empresas


# Tipos de actos que reconocemos
ACTOS_CONOCIDOS = [
    "Constitución",
    "Nombramientos",
    "Ceses/Dimisiones",
    "Revocaciones",
    "Reelecciones",
    "Modificaciones estatutarias",
    "Cambio de objeto social",
    "Cambio de domicilio social",
    "Ampliación de capital",
    "Reducción de capital",
    "Disolución",
    "Extinción",
    "Concurso de acreedores",
    "Situación concursal",
    "Declaración de unipersonalidad",
    "Pérdida del carácter de unipersonalidad",
    "Sociedad unipersonal",
    "Transformación de sociedad",
    "Fusión por absorción",
    "Escisión total",
    "Escisión parcial",
    "Depósito de cuentas anuales",
    "Otros conceptos",
]

ACTOS_RIESGO = [
    "Disolución",
    "Extinción",
    "Concurso de acreedores",
    "Situación concursal",
]


def _clasificar_actos(texto: str) -> list[str]:
    """Identifica los tipos de actos presentes en el texto."""
    encontrados = []
    for acto in ACTOS_CONOCIDOS:
        if acto.lower() in texto.lower():
            encontrados.append(acto)
    return encontrados


def obtener_actos_dia(fecha: date) -> list[dict]:
    """Flujo completo: descarga sumario → XMLs → parsea → devuelve todos los actos del día."""
    sumario = get_sumario(fecha)
    if sumario is None:
        return []

    items = extraer_urls_seccion_a(sumario)
    logger.info("Encontradas %d provincias en Sección A", len(items))

    todos_actos = []
    for item in items:
        if not item["url_xml"]:
            continue
        xml_text = descargar_xml_actos(item["url_xml"])
        if xml_text is None:
            continue
        actos = parsear_xml_actos(xml_text)
        todos_actos.extend(actos)
        logger.info("  %s: %d empresas", item["provincia"], len(actos))

    logger.info("Total empresas procesadas: %d", len(todos_actos))
    return todos_actos


def ultima_fecha_laborable() -> date:
    """Devuelve la última fecha laborable (L-V). Si hoy es lunes, devuelve viernes."""
    hoy = date.today()
    if hoy.weekday() == 0:  # Lunes
        return hoy - timedelta(days=3)
    elif hoy.weekday() == 6:  # Domingo
        return hoy - timedelta(days=2)
    elif hoy.weekday() == 5:  # Sábado
        return hoy - timedelta(days=1)
    return hoy
