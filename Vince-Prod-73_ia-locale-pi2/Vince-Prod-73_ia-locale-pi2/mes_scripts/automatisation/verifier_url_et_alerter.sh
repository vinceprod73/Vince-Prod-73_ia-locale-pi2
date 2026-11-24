#!/bin/bash
# Description: Verifier si une URL repond en HTTP et enregistrer le resultat dans un journal
# Mots-cles: verifier url http statut disponibilite log automatisation bash
URL="${1:-http://127.0.0.1:5000}"
LOG_FILE="${2:-$HOME/ia_locale/verification_url.log}"
HORODATA=$(date "+%Y-%m-%d %H:%M:%S")

CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" || true)
if [ "$CODE" = "200" ]; then
  LIGNE="[$HORODATA] OK ($CODE) - $URL"
else
  LIGNE="[$HORODATA] ALERTE (code=$CODE) - $URL"
fi

echo "$LIGNE"
echo "$LIGNE" >> "$LOG_FILE"
