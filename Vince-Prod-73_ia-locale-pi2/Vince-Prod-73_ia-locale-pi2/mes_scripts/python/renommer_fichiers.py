#!/usr/bin/env python3
# Description: Renommer tous les fichiers d'un dossier avec un prefixe et un numero
# Mots-cles: renommer rename fichiers numero prefixe dossier
import os
import sys

dossier = sys.argv[1] if len(sys.argv) > 1 else "."
prefixe = sys.argv[2] if len(sys.argv) > 2 else "fichier"

fichiers = sorted(f for f in os.listdir(dossier) if os.path.isfile(os.path.join(dossier, f)))
for i, nom in enumerate(fichiers, start=1):
    ext = os.path.splitext(nom)[1]
    nouveau = "%s_%03d%s" % (prefixe, i, ext)
    cible = os.path.join(dossier, nouveau)
    if os.path.exists(cible):
        print("Ignore (existe deja) :", nouveau)
        continue
    os.rename(os.path.join(dossier, nom), cible)
    print(nom, "->", nouveau)
