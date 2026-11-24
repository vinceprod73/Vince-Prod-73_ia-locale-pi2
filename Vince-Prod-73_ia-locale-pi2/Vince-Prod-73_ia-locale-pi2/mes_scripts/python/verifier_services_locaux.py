#!/usr/bin/env python3
# Description: Verifier si l'interface web (5000) et le moteur llama.cpp (8080) repondent en local
# Mots-cles: verifier test port service local 5000 8080 statut python diagnostic
import socket

for nom, port in [("Interface Web Flask", 5000), ("Moteur IA llama.cpp", 8080)]:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(2)
        ok = s.connect_ex(("127.0.0.1", port)) == 0
        print("%s (port %d) : %s" % (nom, port, "ACTIF" if ok else "ARRETE"))
