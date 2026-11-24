#!/bin/bash
# Description: Nettoyer le cache des paquets APT et les anciens journaux systemd pour liberer de la place
# Mots-cles: nettoyer cache apt logs journalctl liberer espace disque maintenance
sudo apt-get autoremove -y
sudo apt-get clean
sudo journalctl --vacuum-time=7d
echo "Nettoyage termine."
