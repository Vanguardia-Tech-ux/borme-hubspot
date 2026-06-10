"""Cliente HubSpot: búsqueda de empresas, creación de notas, actualización de propiedades."""

import logging
from datetime import date

import requests

from .config import HS_PAT, HS_API_BASE

logger = logging.getLogger(__name__)

HEADERS = {
    "Authorization": f"Bearer {HS_PAT}",
    "Content-Type": "application/json",
}

# Propiedades custom del BORME
BORME_PROPERTIES = {
    "ultimo_acto_borme": {"label": "Último acto BORME", "type": "string", "fieldType": "text", "groupName": "companyinformation"},
    "fecha_ultimo_borme": {"label": "Fecha último BORME", "type": "date", "fieldType": "date", "groupName": "companyinformation"},
    "alerta_borme": {"label": "Alerta BORME", "type": "enumeration", "fieldType": "select", "groupName": "companyinformation",
                     "options": [
                         {"label": "Sin cambios", "value": "sin_cambios", "displayOrder": 0},
                         {"label": "Cambio detectado", "value": "cambio_detectado", "displayOrder": 1},
                         {"label": "Alerta riesgo", "value": "alerta_riesgo", "displayOrder": 2},
                     ]},
}


def ensure_properties():
    """Crea las propiedades custom en HubSpot si no existen."""
    for name, config in BORME_PROPERTIES.items():
        url = f"{HS_API_BASE}/crm/v3/properties/companies"
        payload = {"name": name, **config}
        if "options" in payload:
            payload["options"] = config["options"]
        resp = requests.post(url, json=payload, headers=HEADERS, timeout=15)
        if resp.status_code == 201:
            logger.info("Propiedad '%s' creada en HubSpot", name)
        elif resp.status_code == 409:
            logger.debug("Propiedad '%s' ya existe", name)
        else:
            logger.warning("Error creando propiedad '%s': %d %s", name, resp.status_code, resp.text[:200])


def buscar_empresas_por_nombre(nombre: str) -> list[dict]:
    """Busca empresas en HubSpot por nombre."""
    url = f"{HS_API_BASE}/crm/v3/objects/companies/search"
    payload = {
        "filterGroups": [{
            "filters": [{
                "propertyName": "name",
                "operator": "CONTAINS_TOKEN",
                "value": nombre,
            }]
        }],
        "properties": ["name", "domain", "cif_nif", "tipo_de_cliente"],
        "limit": 10,
    }
    resp = requests.post(url, json=payload, headers=HEADERS, timeout=15)
    if resp.status_code != 200:
        logger.warning("Error buscando empresa '%s': %d", nombre, resp.status_code)
        return []
    return resp.json().get("results", [])


def buscar_empresa_por_cif(cif: str) -> dict | None:
    """Busca una empresa en HubSpot por CIF/NIF."""
    url = f"{HS_API_BASE}/crm/v3/objects/companies/search"
    payload = {
        "filterGroups": [{
            "filters": [{
                "propertyName": "cif_nif",
                "operator": "EQ",
                "value": cif,
            }]
        }],
        "properties": ["name", "domain", "cif_nif", "tipo_de_cliente"],
        "limit": 1,
    }
    resp = requests.post(url, json=payload, headers=HEADERS, timeout=15)
    if resp.status_code != 200:
        return None
    results = resp.json().get("results", [])
    return results[0] if results else None


def obtener_todas_empresas() -> list[dict]:
    """Obtiene todas las empresas de HubSpot (paginado)."""
    empresas = []
    url = f"{HS_API_BASE}/crm/v3/objects/companies"
    params = {
        "limit": 100,
        "properties": "name,domain,cif_nif,tipo_de_cliente,alerta_borme",
    }
    while url:
        resp = requests.get(url, params=params, headers=HEADERS, timeout=30)
        if resp.status_code != 200:
            logger.error("Error obteniendo empresas: %d", resp.status_code)
            break
        data = resp.json()
        empresas.extend(data.get("results", []))
        paging = data.get("paging", {}).get("next")
        if paging:
            url = paging["link"]
            params = {}  # La URL ya incluye los params
        else:
            url = None
    logger.info("Obtenidas %d empresas de HubSpot", len(empresas))
    return empresas


def crear_nota(company_id: str, titulo: str, cuerpo: str) -> bool:
    """Crea una nota (engagement) asociada a una empresa."""
    # Crear la nota
    url = f"{HS_API_BASE}/crm/v3/objects/notes"
    payload = {
        "properties": {
            "hs_timestamp": _timestamp_ms(),
            "hs_note_body": f"<strong>{titulo}</strong><br><br>{cuerpo}",
        }
    }
    resp = requests.post(url, json=payload, headers=HEADERS, timeout=15)
    if resp.status_code != 201:
        logger.error("Error creando nota: %d %s", resp.status_code, resp.text[:200])
        return False

    note_id = resp.json()["id"]

    # Asociar nota a empresa
    url = f"{HS_API_BASE}/crm/v4/objects/notes/{note_id}/associations/companies/{company_id}"
    payload = [{"associationCategory": "HUBSPOT_DEFINED", "associationTypeId": 190}]
    resp = requests.put(url, json=payload, headers=HEADERS, timeout=15)
    if resp.status_code not in (200, 201):
        logger.error("Error asociando nota %s a empresa %s: %d", note_id, company_id, resp.status_code)
        return False

    return True


def actualizar_propiedades_borme(company_id: str, actos: list[str], fecha: date, es_riesgo: bool):
    """Actualiza las propiedades BORME de una empresa."""
    alerta = "alerta_riesgo" if es_riesgo else "cambio_detectado"
    url = f"{HS_API_BASE}/crm/v3/objects/companies/{company_id}"
    payload = {
        "properties": {
            "ultimo_acto_borme": ", ".join(actos[:5]),
            "fecha_ultimo_borme": fecha.isoformat(),
            "alerta_borme": alerta,
        }
    }
    resp = requests.patch(url, json=payload, headers=HEADERS, timeout=15)
    if resp.status_code != 200:
        logger.error("Error actualizando empresa %s: %d %s", company_id, resp.status_code, resp.text[:200])
        return False
    return True


def _timestamp_ms() -> str:
    """Timestamp actual en milisegundos."""
    from time import time
    return str(int(time() * 1000))
