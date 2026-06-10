"""Matcher: cruza actos del BORME con empresas de HubSpot."""

import logging
import re
import unicodedata
from collections import defaultdict
from difflib import SequenceMatcher

from .config import MATCH_THRESHOLD
from .borme_client import ACTOS_RIESGO

logger = logging.getLogger(__name__)


def normalizar_nombre(nombre: str) -> str:
    """Normaliza nombre de empresa para comparación.

    Elimina: acentos, tipo societario (SL, SA, SLU, etc.), puntuación.
    """
    # Quitar acentos
    nombre = unicodedata.normalize("NFD", nombre)
    nombre = "".join(c for c in nombre if unicodedata.category(c) != "Mn")

    nombre = nombre.upper().strip()

    # Eliminar formas societarias comunes
    formas = [
        r"\bSOCIEDAD LIMITADA PROFESIONAL\b",
        r"\bSOCIEDAD LIMITADA\b",
        r"\bSOCIEDAD ANONIMA\b",
        r"\bSOCIEDAD COOPERATIVA\b",
        r"\bS\.?L\.?U\.?\b",
        r"\bS\.?L\.?L\.?\b",
        r"\bS\.?L\.?\b",
        r"\bS\.?A\.?\b",
        r"\bS\.?C\.?O\.?O\.?P\.?\b",
    ]
    for forma in formas:
        nombre = re.sub(forma, "", nombre)

    # Quitar puntuación y espacios múltiples
    nombre = re.sub(r"[.,;:'\"-]", "", nombre)
    nombre = re.sub(r"\s+", " ", nombre).strip()

    return nombre


def _extraer_palabras(nombre_norm: str) -> set[str]:
    """Extrae palabras significativas (3+ chars) de un nombre normalizado."""
    return {p for p in nombre_norm.split() if len(p) >= 3}


def _construir_indice_palabras(nombres_dict: dict[str, any]) -> dict[str, list[str]]:
    """Construye un índice invertido: palabra → lista de nombres normalizados que la contienen."""
    indice = defaultdict(list)
    for nombre_norm in nombres_dict:
        for palabra in _extraer_palabras(nombre_norm):
            indice[palabra].append(nombre_norm)
    return indice


def cruzar_borme_hubspot(actos_borme: list[dict], empresas_hubspot: list[dict]) -> list[dict]:
    """Cruza actos del BORME con empresas de HubSpot.

    Estrategia optimizada:
    1. Match exacto por nombre normalizado (O(1) por lookup en dict)
    2. Pre-filtro por palabras compartidas → fuzzy solo en candidatos (evita O(n×m))

    Returns:
        Lista de matches: {empresa_hs, acto_borme, similitud, match_tipo}
    """
    # Indexar empresas HubSpot por nombre normalizado
    hs_por_nombre = {}
    for emp in empresas_hubspot:
        props = emp.get("properties", {})
        nombre = (props.get("name") or "").strip()
        if nombre:
            hs_por_nombre[normalizar_nombre(nombre)] = emp

    # Índice invertido por palabras para búsqueda rápida
    indice_palabras = _construir_indice_palabras(hs_por_nombre)

    matches = []
    stats = {"exactos": 0, "fuzzy": 0, "candidatos_evaluados": 0}

    for acto in actos_borme:
        nombre_borme = acto["nombre"]
        nombre_norm = normalizar_nombre(nombre_borme)

        # 1. Match exacto por nombre normalizado
        if nombre_norm in hs_por_nombre:
            emp = hs_por_nombre[nombre_norm]
            matches.append({
                "empresa_hs": emp,
                "acto_borme": acto,
                "similitud": 1.0,
                "match_tipo": "nombre_exacto",
                "es_riesgo": any(a in ACTOS_RIESGO for a in acto.get("actos", [])),
            })
            stats["exactos"] += 1
            continue

        # 2. Pre-filtro: solo comparar con empresas que comparten al menos 1 palabra
        palabras_borme = _extraer_palabras(nombre_norm)
        candidatos = set()
        for palabra in palabras_borme:
            for nombre_hs in indice_palabras.get(palabra, []):
                candidatos.add(nombre_hs)

        # Fuzzy match solo contra candidatos (típicamente <50 en vez de 17.000)
        mejor_sim = 0.0
        mejor_emp = None
        for nombre_hs in candidatos:
            stats["candidatos_evaluados"] += 1
            sim = SequenceMatcher(None, nombre_norm, nombre_hs).ratio()
            if sim > mejor_sim:
                mejor_sim = sim
                mejor_emp = hs_por_nombre[nombre_hs]

        if mejor_sim >= MATCH_THRESHOLD and mejor_emp is not None:
            matches.append({
                "empresa_hs": mejor_emp,
                "acto_borme": acto,
                "similitud": mejor_sim,
                "match_tipo": "nombre_fuzzy",
                "es_riesgo": any(a in ACTOS_RIESGO for a in acto.get("actos", [])),
            })
            stats["fuzzy"] += 1

    logger.info(
        "Matching completado: %d matches (%d exactos, %d fuzzy). "
        "Candidatos evaluados: %d (de %d×%d posibles)",
        len(matches), stats["exactos"], stats["fuzzy"],
        stats["candidatos_evaluados"], len(actos_borme), len(hs_por_nombre),
    )
    return matches
