#!/bin/bash
# Description: Lister les 20 plus gros fichiers d'un dossier
# Mots-cles: espace disque gros fichiers taille nettoyer liberer place
DOSSIER="${1:-$HOME}"
find "$DOSSIER" -type f -printf '%s %p\n' 2>/dev/null | sort -nr | head -20 | \
  awk '{ taille=$1; $1=""; printf "%.1f Mo  %s\n", taille/1048576, $0 }'
