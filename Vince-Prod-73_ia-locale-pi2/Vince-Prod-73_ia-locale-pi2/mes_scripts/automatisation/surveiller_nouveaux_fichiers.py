#!/usr/bin/env python3
# Description: Surveiller un dossier a intervalle regulier et afficher les nouveaux fichiers detectes
# Mots-cles: surveiller watcher nouveaux fichiers boucle intervalle automatisation python
import os
import sys
import time

dossier = sys.argv[1] if len(sys.argv) > 1 else "."
intervalle = int(sys.argv[2]) if len(sys.argv) > 2 else 10

if not os.path.isdir(dossier):
    print("Dossier introuvable :", dossier)
    sys.exit(1)

connus = set(os.listdir(dossier))
print("Surveillance de %s toutes les %ds (Ctrl+C pour arreter)..." % (dossier, intervalle))
try:
    while True:
        time.sleep(intervalle)
        actuels = set(os.listdir(dossier))
        nouveaux = sorted(actuels - connus)
        for nom in nouveaux:
            print("[%s] Nouveau fichier : %s" % (time.strftime("%H:%M:%S"), nom))
        connus = actuels
except KeyboardInterrupt:
    print("Surveillance arretee.")
