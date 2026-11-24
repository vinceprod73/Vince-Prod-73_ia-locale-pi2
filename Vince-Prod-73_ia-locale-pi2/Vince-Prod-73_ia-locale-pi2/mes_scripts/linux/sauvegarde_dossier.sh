#!/bin/bash
# Description: Sauvegarder un dossier dans une archive datee (.tar.gz)
# Mots-cles: sauvegarde backup archive tar compresser dossier copie
SRC="${1:-$HOME/Documents}"
DEST="${2:-$HOME/sauvegardes}"
mkdir -p "$DEST"
FICHIER="$DEST/sauvegarde_$(date +%Y-%m-%d_%H%M).tar.gz"
tar -czf "$FICHIER" -C "$(dirname "$SRC")" "$(basename "$SRC")"
echo "Sauvegarde creee : $FICHIER"
