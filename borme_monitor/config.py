import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

# HubSpot
HS_PAT = os.getenv("HS_PAT")
HS_API_BASE = "https://api.hubapi.com"

# Email
GMAIL_USER = os.getenv("GMAIL_USER")
GMAIL_PASS = os.getenv("GMAIL_PASS")
ALERT_EMAIL = os.getenv("ALERT_EMAIL")

# BORME API
BORME_API_BASE = "https://www.boe.es/datosabiertos/api/borme/sumario"
BORME_PDF_BASE = "https://www.boe.es"

# Matching
MATCH_THRESHOLD = float(os.getenv("MATCH_THRESHOLD", "0.90"))

# Directorios
DATA_DIR = BASE_DIR / "data"
LOGS_DIR = BASE_DIR / "logs"
DATA_DIR.mkdir(exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)
