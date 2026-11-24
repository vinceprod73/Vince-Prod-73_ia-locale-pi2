# IA Locale pour Raspberry Pi 2 / Local AI for Raspberry Pi 2

🇬🇧 **English** | 🇫🇷 [Français](#version-française)

## English summary

A small **100% local, offline AI** for the **Raspberry Pi 2** (1 GB RAM). No cloud, no API key.

- **Searches your own files**: text notes (`.txt`, `.md`) and scripts (Bash, Python, etc.).
- **Generates small programs** with a real language model ([llama.cpp](https://github.com/ggml-org/llama.cpp) + Qwen2.5-Coder 0.5B), using your own library as context.
- Simple web interface (Flask) on your local network: `http://<pi-ip>:5000`.
- One-command install, systemd services for auto-start, 36 starter notes and 10 example scripts (in French).

**Quick install** (Raspberry Pi OS, internet required):

```bash
git clone https://github.com/vinceprod73/ia-locale-pi2.git
cd ia-locale-pi2
chmod +x install_ia_locale.sh
./install_ia_locale.sh
```

**Honest expectations:** a 0.5B model on a Pi 2 is slow (a few tokens per second) and limited. Ask for one precise task at a time and always review code before running it. Building llama.cpp takes a long time on a Pi 2 (32-bit ARM, 1 GB RAM). The web interface has no password: keep it on your local network and never expose it to the Internet.

Released under the MIT license. The notes and interface are in French.

---

## Version française

# IA Locale pour Raspberry Pi 2

Une petite IA **100 % locale**, sans cloud ni clé API, pensée pour un **Raspberry Pi 2** (1 Go de RAM).
Elle fait deux choses :

1. **Recherche dans tes propres fichiers** : tes fiches texte (`.txt`, `.md`) et tes scripts (Bash, Python, etc.).
2. **Génération de petits programmes** avec un vrai modèle de langage ([llama.cpp](https://github.com/ggml-org/llama.cpp) + Qwen2.5-Coder 0.5B), qui s'appuie sur tes dossiers.

Tu l'utilises depuis n'importe quel navigateur de ton réseau local : `http://<ip-du-pi>:5000`.

> **Soyons honnêtes sur les performances** : un modèle de 0,5 milliard de paramètres sur un Pi 2 est lent
> (quelques tokens par seconde) et limité. Compte plusieurs minutes pour un script complet, demande une tâche
> précise à la fois, et **relis toujours le code avant de l'exécuter**. La vraie force du projet est la
> bibliothèque personnelle que tu enrichis.

## Fonctionnalités

- Interface web simple (Flask), réponse en streaming, bouton Stop.
- Mode « Programme / Script » pour orienter la génération.
- Bouton « Ajouter à ma bibliothèque » : enregistre le code généré dans `mes_scripts/automatisation/` avec description et mots-clés.
- Recherche dans les textes avec index automatique, sous-dossiers autorisés.
- 36 fiches de départ (développement, Linux, réseau, sécurité, culture générale…) et 10 scripts d'exemple.
- Services systemd : démarrage automatique au boot.

## Installation

Sur Raspberry Pi OS, connecté à Internet :

```bash
git clone https://github.com/vinceprod73/ia-locale-pi2.git
cd ia-locale-pi2
chmod +x install_ia_locale.sh
./install_ia_locale.sh
```

L'installateur :

1. installe les outils (`python3-flask`, `git`, `cmake`, `build-essential`, `curl`) ;
2. copie l'application et tes dossiers dans `~/ia_locale` (sans écraser l'existant) ;
3. crée le service web (port 5000) ;
4. ajoute un swap temporaire de 1 Go, compile `llama-server` (**long, plusieurs dizaines de minutes**) ;
5. télécharge le modèle (~490 Mo) et crée le service du moteur IA.

Le moteur met 1 à 2 minutes à charger après chaque démarrage. Le script est relançable : le téléchargement reprend là où il s'est arrêté.

## Utilisation

- Ouvre `http://<ip-du-pi>:5000`.
- Ajoute tes fiches dans `~/ia_locale/mes_textes/` (sépare chaque idée par une ligne vide) et tes scripts dans `~/ia_locale/mes_scripts/`.
- Pour qu'un script soit bien retrouvé, mets en tête de fichier :
  ```
  # Description: ce que fait le script
  # Mots-cles: mot1 mot2 mot3
  ```

Le guide détaillé est dans [`docs/Aide-memoire_IA_Locale_Pi2_v4.txt`](docs/Aide-memoire_IA_Locale_Pi2_v4.txt).

## Structure

```
install_ia_locale.sh   installateur complet
app/server.py          serveur web + recherche + client llama.cpp
mes_textes/            fiches de connaissances
mes_scripts/           scripts d'exemple
docs/                  aide-mémoire
```

## Sécurité

- L'interface écoute sur `0.0.0.0:5000` **sans mot de passe** : garde-la sur ton réseau local, **n'ouvre jamais ce port sur Internet**.
- Elle peut enregistrer des fichiers dans `mes_scripts/` et les télécharger.
- Le moteur llama.cpp n'écoute qu'en local (`127.0.0.1:8080`).

## Dépannage

- **Compilation échouée / mémoire** : relance le script ; vérifie le swap (`free -h`). Le Pi 2 en 32 bits est la plateforme la plus délicate pour llama.cpp.
- **Pas de réponse de l'IA** : `sudo systemctl status llm_local` et `journalctl -u llm_local -n 50`.
- **Interface inaccessible** : `sudo systemctl status ia_locale`.

## Licences des composants

Ce projet est sous licence **MIT** (voir [`LICENSE`](LICENSE)). Il utilise, sans les redistribuer :
llama.cpp (MIT), le modèle Qwen2.5-Coder 0.5B Instruct GGUF (téléchargé depuis Hugging Face ; vérifie sa licence actuelle) et Flask (BSD-3).

## Contribuer

Les idées et corrections sont les bienvenues via issues et pull requests. Merci de tester sur un vrai Raspberry Pi quand c'est possible.

---
Créé par **Vince Prod 73**
