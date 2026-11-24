#!/bin/bash
# Description: Afficher la temperature CPU, la memoire RAM et l'espace disque du Raspberry Pi
# Mots-cles: temperature cpu ram memoire disque sante raspberry pi diagnostic
echo "=== Temperature CPU ==="
vcgencmd measure_temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp
echo "=== Memoire RAM et Swap ==="
free -h
echo "=== Espace disque ==="
df -h /
