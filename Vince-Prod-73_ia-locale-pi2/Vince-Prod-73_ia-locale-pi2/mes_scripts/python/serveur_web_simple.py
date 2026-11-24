#!/usr/bin/env python3
# Description: Partager un dossier sur le reseau local avec un mini serveur web
# Mots-cles: serveur web http partager dossier reseau local port
import http.server
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
with socketserver.TCPServer(("", PORT), http.server.SimpleHTTPRequestHandler) as httpd:
    print("Serveur sur http://0.0.0.0:%d (Ctrl+C pour arreter)" % PORT)
    httpd.serve_forever()
