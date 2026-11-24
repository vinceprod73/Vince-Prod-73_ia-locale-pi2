#!/usr/bin/env python3
# Description: Classer automatiquement les fichiers d'un dossier dans des sous-dossiers par extension
# Mots-cles: automatiser organiser trier ranger fichiers extension dossier python
import os
import shutil
import sys

source = sys.argv[1] if len(sys.argv) > 1 else "."
if not os.path.isdir(source):
    print("Dossier introuvable :", source)
    sys.exit(1)

for nom in sorted(os.listdir(source)):
    chemin = os.path.join(source, nom)
    if not os.path.isfile(chemin):
        continue
    ext = os.path.splitext(nom)[1].lower().lstrip(".")
    dossier_cible = os.path.join(source, ext if ext else "sans_extension")
    os.makedirs(dossier_cible, exist_ok=True)
    cible = os.path.join(dossier_cible, nom)
    if os.path.exists(cible):
        print("Ignore (deja present) :", cible)
        continue
    shutil.move(chemin, cible)
    print("Deplace :", nom, "->", dossier_cible)
