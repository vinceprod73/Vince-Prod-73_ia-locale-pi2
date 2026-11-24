#!/bin/bash
# Créé par Vince Prod 73
set -e

APP_DIR="$HOME/ia_locale"
DOCS_DIR="$APP_DIR/mes_textes"
SCRIPTS_DIR="$APP_DIR/mes_scripts"
MODEL_DIR="$APP_DIR/modeles"
LLAMA_DIR="$HOME/llama.cpp"
MODEL_FILE="$MODEL_DIR/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"

echo "=== 1/7 : Installation des outils ==="
sudo apt-get update
sudo apt-get install -y python3 python3-flask git cmake build-essential curl

echo "=== 2/7 : Creation des dossiers ==="
mkdir -p "$DOCS_DIR"
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$MODEL_DIR"
mkdir -p "$APP_DIR/app"

echo "=== 3/7 : Creation du serveur web (recherche + interface IA) ==="
cat << 'EOF' > "$APP_DIR/app/server.py"
# Créé par Vince Prod 73
import os
import re
import glob
import json
import math
import hashlib
import threading
import unicodedata
import urllib.request
from collections import Counter
from flask import Flask, request, render_template_string, send_file, abort, Response, stream_with_context, jsonify

BASE = os.path.expanduser("~/ia_locale")
TEXTES = os.path.join(BASE, "mes_textes")
SCRIPTS = os.path.join(BASE, "mes_scripts")
FEEDBACK_FILE = os.path.join(BASE, "app", "feedback.json")
EXT_TEXTE = (".txt", ".md")
EXT_CODE = {
    ".sh": "Bash", ".py": "Python", ".js": "JavaScript", ".html": "HTML",
    ".css": "CSS", ".ps1": "PowerShell", ".bat": "Batch", ".c": "C",
    ".cpp": "C++", ".h": "C/C++", ".java": "Java", ".php": "PHP",
    ".sql": "SQL", ".json": "JSON", ".yml": "YAML", ".yaml": "YAML",
    ".ini": "INI", ".conf": "Config", ".lua": "Lua", ".rs": "Rust", ".go": "Go",
}
MAX_CODE = 100000

# ---- Reglages du moteur IA (llama.cpp) ----
LLM_URL = "http://127.0.0.1:8080/v1/chat/completions"
MAX_CONTEXTE = 950    # caracteres max de tes dossiers envoyes a l'IA (optimise Pi 2)
MAX_REPONSE = 320     # longueur max de la reponse (en tokens, adapte aux petits programmes)
TAILLE_MEMOIRE = 60   # nombre de reponses gardees en memoire
SYSTEME = ("Tu es un assistant de programmation et d'automatisation en francais. "
           "Reponds de facon courte, concrete et fiable. "
           "Quand on te demande un programme ou script : donne un code complet, autonome et commente dans un bloc, "
           "puis une explication courte en 2 ou 3 phrases. "
           "Utilise les documents fournis s'ils aident. Si tu n'es pas sur, dis-le clairement.")
app = Flask(__name__)
VERROU = threading.Lock()
MEMOIRE = {}

HTML_PAGE = r"""
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>IA Locale - Programmes, Scripts &amp; Connaissances</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 920px; margin: 32px auto; padding: 0 16px; line-height: 1.5; background: #faf8f9; color: #222; }
    h1 { color: #A22846; }
    input[type=text], select { padding: 10px; font-size: 15px; border: 1px solid #ccc; border-radius: 6px; }
    input[type=text] { width: 70%; }
    button { padding: 10px 16px; font-size: 15px; cursor: pointer; background: #A22846; color: #fff; border: none; border-radius: 6px; }
    button:hover { background: #851f38; }
    .retour { background: #eef7ea; border-left: 5px solid #6CC04A; padding: 16px; border-radius: 6px; margin-top: 20px; }
    .bloc { background: #ffffff; border: 1px solid #e5e5e5; padding: 14px; border-radius: 6px; margin-top: 14px; }
    .source { font-weight: bold; color: #A22846; }
    .petit { font-size: 13px; color: #555; }
    pre { background: #1e1e1e; color: #eaeaea; padding: 12px; border-radius: 6px; overflow: auto; max-height: 440px; font-size: 13px; white-space: pre; }
    .btn-petit { font-size: 13px; padding: 6px 10px; margin-top: 8px; margin-right: 6px; background: #6CC04A; color: #fff; }
    .btn-petit:hover { background: #58a638; }
    .btn-secondaire { background: #4a5568; }
    .btn-secondaire:hover { background: #2d3748; }
    .lien { font-size: 13px; margin-left: 8px; color: #A22846; }
    summary { cursor: pointer; }
    .save-box { background: #f7f9fc; border: 1px dashed #94a3b8; padding: 10px; border-radius: 6px; margin-top: 10px; }
    .save-box input { width: auto; padding: 6px 8px; font-size: 13px; margin: 4px 6px 4px 0; }
  </style>
  <script>
    function copier(id) {
      var el = document.getElementById(id);
      var t = document.createElement('textarea');
      t.value = el.textContent;
      document.body.appendChild(t);
      t.select();
      try { document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(t);
      alert('Copie dans le presse-papiers !');
    }
    function extraireBlocCode(texte) {
      var m = texte.match(/```[a-zA-Z0-9_-]*\n([\s\S]*?)```/);
      return m ? m[1].trim() : texte.trim();
    }
    async function enregistrerProgramme() {
      var repText = document.getElementById('repIA').textContent;
      var code = extraireBlocCode(repText);
      var nom = document.getElementById('nomProg').value.trim();
      var desc = document.getElementById('descProg').value.trim();
      var mcles = document.getElementById('mclesProg').value.trim();
      var statut = document.getElementById('statutSave');
      if (!code || !nom) {
        statut.textContent = 'Indique au moins un nom de fichier (ex: mon_script.py).';
        return;
      }
      var fd = new FormData();
      fd.append('nom_fichier', nom);
      fd.append('description', desc);
      fd.append('mots_cles', mcles);
      fd.append('code', code);
      try {
        var r = await fetch('/sauvegarder_script', { method: 'POST', body: fd });
        var j = await r.json();
        statut.textContent = j.message || 'Enregistre.';
      } catch (e) {
        statut.textContent = 'Erreur lors de la sauvegarde.';
      }
    }
  </script>
</head>
<body>
  <h1>IA Locale - Programmes, Scripts &amp; Connaissances</h1>
  <p class="petit">Scripts dans <code>~/ia_locale/mes_scripts</code> | Textes (.txt, .md) dans <code>~/ia_locale/mes_textes</code> (sous-dossiers autorises).</p>

  <div class="bloc">
    <h2 style="margin-top:0">Construire un petit programme ou demander a l'IA</h2>
    <form id="formIA">
      <input type="text" id="qIA" placeholder="Ex : ecris un script python qui classe les fichiers d'un dossier par extension" required>
      <select id="modeProg" title="Type de demande">
        <option value="auto">Auto</option>
        <option value="programme">Programme / Script</option>
      </select>
      <button type="submit">Generer</button>
      <br><label class="petit"><input type="checkbox" id="doss" checked> Utiliser mes dossiers (scripts et fiches d'automatisation)</label>
      <br><label class="petit"><input type="checkbox" id="frais"> Nouvelle reponse (ignorer la memoire des reponses deja donnees)</label>
    </form>
    <p class="petit">Conseil : demande une tache precise a la fois. Sur Pi 2, compte plusieurs minutes pour une generation complete.</p>
    <pre id="repIA" style="display:none; white-space:pre-wrap;"></pre>
    <div id="actionsIA" style="display:none;">
      <button type="button" class="btn-petit" onclick="copier('repIA')">Copier la reponse</button>
      <button type="button" class="btn-petit btn-secondaire" id="stopIA">Stop</button>
      <div class="save-box">
        <div class="petit"><strong>Enregistrer le programme dans mes_scripts/automatisation/ :</strong></div>
        <input type="text" id="nomProg" placeholder="nom_programme.py">
        <input type="text" id="descProg" placeholder="Description courte">
        <input type="text" id="mclesProg" placeholder="mots-cles automatisation...">
        <button type="button" class="btn-petit" onclick="enregistrerProgramme()">Ajouter a ma bibliotheque</button>
        <div id="statutSave" class="petit"></div>
      </div>
    </div>
  </div>

  <h3>Ou chercher seulement dans mes dossiers (instantane)</h3>
  <form method="post" action="/">
    <input type="text" name="question" placeholder="Ex : automatiser classement fichiers ou cron" value="{{ question or '' }}" required>
    <button type="submit">Chercher</button>
  </form>

  {% if retour is not none %}
    {% if retour.scripts %}
      <div class="retour">
        <h2>Scripts trouves dans votre bibliotheque</h2>
        {% for s in retour.scripts %}
          <details class="bloc" {% if loop.first %}open{% endif %}>
            <summary><span class="source">{{ s.fichier }}</span> <span class="petit">({{ s.langage }} | score : {{ s.score }} | bonus : +{{ s.bonus }}%)</span></summary>
            {% if s.desc %}<p>{{ s.desc }}</p>{% endif %}
            <pre id="code{{ loop.index }}">{{ s.code }}</pre>
            <button type="button" class="btn-petit" onclick="copier('code{{ loop.index }}')">Copier</button>
            <a class="lien" href="/telecharger?f={{ s.fichier | urlencode }}">Telecharger</a>
            <form method="post" action="/vote" style="display:inline;">
              <input type="hidden" name="cle" value="{{ s.cle }}">
              <input type="hidden" name="question" value="{{ question }}">
              <button type="submit" class="btn-petit">Pertinent (+1)</button>
            </form>
          </details>
        {% endfor %}
      </div>
    {% endif %}

    {% if retour.resume %}
      <div class="retour">
        <h2>Dans vos textes</h2>
        <p>{{ retour.resume }}</p>
        <p class="petit"><strong>Sources consultees :</strong> {{ retour.sources | join(", ") }}</p>
      </div>
      <h3>Passages detailles utilises</h3>
      {% for r in retour.textes %}
        <div class="bloc">
          <div class="source">{{ r.fichier }} <span class="petit">(score : {{ r.score }} | bonus : +{{ r.bonus }}%)</span></div>
          <p>{{ r.extrait }}</p>
          <form method="post" action="/vote" style="display:inline;">
            <input type="hidden" name="cle" value="{{ r.cle }}">
            <input type="hidden" name="question" value="{{ question }}">
            <button type="submit" class="btn-petit">Pertinent (+1)</button>
          </form>
        </div>
      {% endfor %}
    {% endif %}

    {% if not retour.scripts and not retour.resume %}
      <div class="retour">
        <p>Rien d'assez proche dans votre bibliotheque. Ajoutez un script dans <code>~/ia_locale/mes_scripts</code> ou un texte dans <code>~/ia_locale/mes_textes</code> pour enrichir mes reponses.</p>
      </div>
    {% endif %}
  {% endif %}
  <script>
    var ctrl = null;
    async function demanderIA(ev) {
      ev.preventDefault();
      var q = document.getElementById('qIA').value.trim();
      if (!q) { return; }
      var mode = document.getElementById('modeProg').value;
      if (mode === 'programme' && !/script|programme|code|python|bash/i.test(q)) {
        q = 'Ecris un petit programme automatise clair et complet pour : ' + q;
      }
      var sortie = document.getElementById('repIA');
      var actions = document.getElementById('actionsIA');
      sortie.style.display = 'block';
      actions.style.display = 'block';
      document.getElementById('statutSave').textContent = '';
      sortie.textContent = 'Reflexion en cours... (patience, le Pi 2 est lent)';
      var fd = new FormData();
      fd.append('question', q);
      fd.append('mode', mode);
      fd.append('dossiers', document.getElementById('doss').checked ? '1' : '0');
      fd.append('frais', document.getElementById('frais').checked ? '1' : '0');
      ctrl = new AbortController();
      try {
        var rep = await fetch('/ask', { method: 'POST', body: fd, signal: ctrl.signal });
        var lecteur = rep.body.getReader();
        var deco = new TextDecoder('utf-8');
        var premier = true;
        while (true) {
          var etat = await lecteur.read();
          if (etat.done) { break; }
          if (premier) { sortie.textContent = ''; premier = false; }
          sortie.textContent += deco.decode(etat.value, { stream: true });
        }
      } catch (e) {
        if (e.name !== 'AbortError') { sortie.textContent += ' [Connexion interrompue]'; }
      }
    }
    document.getElementById('formIA').addEventListener('submit', demanderIA);
    document.getElementById('stopIA').addEventListener('click', function () { if (ctrl) { ctrl.abort(); } });
  </script>
</body>
</html>
"""

def normaliser(texte):
    texte = unicodedata.normalize("NFD", texte.lower())
    return "".join(c for c in texte if unicodedata.category(c) != "Mn")

MOTS_VIDES = set(normaliser(m) for m in (
    "le la les un une des du de d l au aux et ou en a est sont ce ces cet cette "
    "qui que quoi dont ne pas plus par pour sur sous dans avec sans il elle ils "
    "elles on je tu nous vous se sa son ses leur leurs mais donc car ni y ete "
    "etre avoir fait comme quel quelle quels quelles ca qu "
    "moi me te ta ton mon ma mes tes donne donner ecris ecrire fais faire cree "
    "creer veux voudrais besoin peux pourrais svp merci s il vous plait"
).split())

SUFFIXES = (
    "ements", "ement", "ations", "ation", "ences", "ence", "eurs", "eur",
    "ages", "age", "ions", "ion", "iques", "ique", "ifs", "if",
    "ers", "er", "ez", "es", "ent", "e", "s", "x"
)

def racine(m):
    if m.endswith("eaux"):
        return m[:-1]
    for suf in SUFFIXES:
        if m.endswith(suf) and len(m) - len(suf) >= 4:
            return m[:-len(suf)]
    return m

def mots(texte):
    resultat = []
    for m in re.findall(r"[a-z0-9]+", normaliser(texte)):
        if len(m) < 2 or m in MOTS_VIDES:
            continue
        resultat.append(racine(m))
    return resultat

CODE_MOTS = set(mots("script code programme programmer automatiser automatisation fonction python bash shell html css "
                     "javascript php sql boucle variable classe algorithme commande powershell batch fichier dossier cron log"))

def couper_proprement(texte, limite):
    if len(texte) <= limite:
        return texte
    tronque = texte[:limite]
    pos = tronque.rfind("\n")
    if pos >= int(limite * 0.6):
        return tronque[:pos].strip()
    return tronque.strip()

def meilleures_phrases(texte, requete, limite):
    if len(texte) <= limite:
        return texte
    phrases = [p.strip() for p in re.split(r"(?<=[.!?])\s+|\n+", texte) if p.strip()]
    if len(phrases) <= 1:
        return couper_proprement(texte, limite)
    notees = sorted(((len(requete & set(mots(ph))), -i, i, ph) for i, ph in enumerate(phrases)),
                    reverse=True)
    choisies, total = [], 0
    for _, _, i, ph in notees:
        if choisies and total + len(ph) > limite:
            continue
        choisies.append((i, ph))
        total += len(ph) + 1
        if total >= limite:
            break
    choisies.sort()
    return couper_proprement(" ".join(ph for _, ph in choisies), limite)

def lire(chemin):
    with open(chemin, "r", encoding="utf-8", errors="replace") as f:
        return f.read()

PREFIXE = r"^(?:#|//|--|rem\b|::|/\*|\*)\s*"

def lire_meta(texte):
    desc, cles = "", ""
    for ligne in texte.splitlines()[:25]:
        l = ligne.strip()
        m = re.match(PREFIXE + r"(?:description|desc)\s*:\s*(.+)$", l, re.I)
        if m and not desc:
            desc = m.group(1).strip(" */")
        m = re.match(PREFIXE + r"mots?[- ]?cl[e\u00e9]s?\s*:\s*(.+)$", l, re.I)
        if m and not cles:
            cles = m.group(1).strip(" */")
    return desc, cles

GROUPES = {"texte": {}, "code": {}}
SIGNATURE = [None]

def lister():
    fichiers = []
    for ext in EXT_TEXTE:
        for c in glob.glob(os.path.join(TEXTES, "**/*" + ext), recursive=True):
            fichiers.append(("texte", c))
    for ext in EXT_CODE:
        for c in glob.glob(os.path.join(SCRIPTS, "**/*" + ext), recursive=True):
            fichiers.append(("code", c))
    return fichiers

def signature(fichiers):
    sig = []
    for genre, c in fichiers:
        try:
            sig.append((genre, c, os.path.getmtime(c)))
        except OSError:
            pass
    return tuple(sorted(sig))

def construire_groupe(passages):
    df = Counter()
    for p in passages:
        df.update(p["tf"].keys())
    total = sum(p["longueur"] for p in passages)
    return {"passages": passages, "df": df,
            "moyenne": (total / len(passages)) if passages else 1.0}

def charger_index():
    with VERROU:
        fichiers = lister()
        sig = signature(fichiers)
        if sig == SIGNATURE[0]:
            return sig
        textes, codes = [], []
        for genre, chemin, _ in sig:
            try:
                contenu = lire(chemin)
            except Exception:
                continue
            if genre == "texte":
                nom = os.path.relpath(chemin, TEXTES)
                for bloc in re.split(r"\n\s*\n", contenu):
                    bloc = bloc.strip()
                    if len(bloc) <= 20:
                        continue
                    liste = mots(bloc)
                    if not liste:
                        continue
                    textes.append({
                        "cle": hashlib.md5(bloc.encode("utf-8")).hexdigest()[:12],
                        "fichier": nom, "texte": bloc,
                        "tf": Counter(liste), "longueur": len(liste)})
            else:
                contenu = contenu[:MAX_CODE]
                nom = os.path.relpath(chemin, SCRIPTS)
                base = os.path.splitext(os.path.basename(chemin))[0].replace("_", " ").replace("-", " ")
                dossier = os.path.dirname(nom).replace(os.sep, " ")
                ext = os.path.splitext(chemin)[1].lower()
                desc, cles = lire_meta(contenu)
                renfort = ((base + " ") * 3 + (dossier + " ") * 2 +
                           (desc + " ") * 3 + (cles + " ") * 4)
                liste = mots(renfort + contenu[:3000])
                if not liste:
                    continue
                codes.append({
                    "cle": hashlib.md5(contenu.encode("utf-8")).hexdigest()[:12],
                    "fichier": nom, "code": contenu, "desc": desc,
                    "langage": EXT_CODE.get(ext, "Code"),
                    "tf": Counter(liste), "longueur": len(liste)})
        GROUPES["texte"] = construire_groupe(textes)
        GROUPES["code"] = construire_groupe(codes)
        SIGNATURE[0] = sig
        return sig

def charger_feedback():
    if os.path.exists(FEEDBACK_FILE):
        try:
            with open(FEEDBACK_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def sauvegarder_feedback(data):
    tmp = FEEDBACK_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, FEEDBACK_FILE)

def noter(groupe, requete, feedback):
    passages = groupe.get("passages", [])
    if not passages:
        return []
    N = len(passages)
    moyenne = groupe["moyenne"]
    k1, b = 1.5, 0.75
    notes = []
    for p in passages:
        score = 0.0
        for t in requete:
            f = p["tf"].get(t, 0)
            if not f:
                continue
            n = groupe["df"][t]
            idf = math.log(1 + (N - n + 0.5) / (n + 0.5))
            score += idf * f * (k1 + 1) / (f + k1 * (1 - b + b * p["longueur"] / moyenne))
        if score > 0:
            pct = min(feedback.get(p["cle"], 0) * 10, 50)
            notes.append((score * (1 + pct / 100.0), pct, p))
    notes.sort(key=lambda x: x[0], reverse=True)
    return notes

def fabriquer_resume(textes):
    if not textes:
        return {"resume": None, "sources": []}
    phrases, sources = [], []
    for r in textes[:3]:
        if r["fichier"] not in sources:
            sources.append(r["fichier"])
        for ph in re.split(r"(?<=[.!?])\s+", r["extrait"].strip()):
            ph = ph.strip()
            if len(ph) > 25 and ph not in phrases:
                phrases.append(ph)
                break
    resume = " ".join(phrases[:3])
    return {"resume": resume if resume else textes[0]["extrait"][:400],
            "sources": sources}

def interroger_avec_index(question, feedback):
    requete = set(mots(question))
    retour = {"resume": None, "sources": [], "scripts": [], "textes": []}
    if not requete:
        return retour

    for total, pct, p in noter(GROUPES["code"], requete, feedback)[:3]:
        retour["scripts"].append({
            "cle": p["cle"], "fichier": p["fichier"], "langage": p["langage"],
            "desc": p["desc"], "code": p["code"],
            "couverture": len(requete & set(p["tf"])) / float(len(requete)),
            "score": round(total, 2), "bonus": pct})

    for total, pct, p in noter(GROUPES["texte"], requete, feedback)[:5]:
        retour["textes"].append({
            "cle": p["cle"], "fichier": p["fichier"],
            "score": round(total, 2), "bonus": pct,
            "couverture": len(requete & set(p["tf"])) / float(len(requete)),
            "complet": p["texte"],
            "extrait": p["texte"][:600]})

    retour.update(fabriquer_resume(retour["textes"]))
    return retour

def interroger(question):
    charger_index()
    return interroger_avec_index(question, charger_feedback())

def construire_contexte(question, feedback=None, mode_prog=False):
    requete = set(mots(question))
    if not requete:
        return ""
    if feedback is None:
        feedback = charger_feedback()
    retour = interroger_avec_index(question, feedback)

    def bons(liste, seuil):
        if not liste:
            return []
        meilleur = liste[0]["score"]
        return [x for x in liste if x["score"] >= 0.65 * meilleur and x["couverture"] >= seuil]

    morceaux = []
    if mode_prog or (requete & CODE_MOTS):
        for sc in bons(retour["scripts"], 0.34)[:1]:
            morceaux.append("[Script exemple : %s]\n%s" % (sc["fichier"], couper_proprement(sc["code"], 650)))
        for t in bons(retour["textes"], 0.50)[:1]:
            morceaux.append("[Methode : %s]\n%s" % (t["fichier"], meilleures_phrases(t["complet"], requete, 280)))
    else:
        for t in bons(retour["textes"], 0.34)[:2]:
            morceaux.append("[Note : %s]\n%s" % (t["fichier"], meilleures_phrases(t["complet"], requete, 350)))
        for sc in bons(retour["scripts"], 0.67)[:1]:
            morceaux.append("[Script : %s]\n%s" % (sc["fichier"], couper_proprement(sc["code"], 550)))
    return couper_proprement("\n\n".join(morceaux), MAX_CONTEXTE)

@app.route("/", methods=["GET", "POST"])
def index():
    question = ""
    retour = None
    if request.method == "POST":
        question = request.form.get("question", "").strip()
        if question:
            retour = interroger(question)
    return render_template_string(HTML_PAGE, question=question, retour=retour)

@app.route("/vote", methods=["POST"])
def vote():
    cle = request.form.get("cle", "").strip()
    question = request.form.get("question", "").strip()
    if cle:
        with VERROU:
            fb = charger_feedback()
            fb[cle] = fb.get(cle, 0) + 1
            sauvegarder_feedback(fb)
    retour = interroger(question) if question else None
    return render_template_string(HTML_PAGE, question=question, retour=retour)

@app.route("/sauvegarder_script", methods=["POST"])
def sauvegarder_script():
    nom = os.path.basename(request.form.get("nom_fichier", "").strip())
    desc = request.form.get("description", "").strip()
    mcles = request.form.get("mots_cles", "").strip()
    code = request.form.get("code", "")
    if not nom or not code.strip():
        return jsonify({"ok": False, "message": "Nom ou code manquant."}), 400
    ext = os.path.splitext(nom)[1].lower()
    if ext not in EXT_CODE:
        nom = nom + ".py"
        ext = ".py"
    cible_dir = os.path.join(SCRIPTS, "automatisation")
    os.makedirs(cible_dir, exist_ok=True)
    cible = os.path.realpath(os.path.join(cible_dir, nom))
    if not cible.startswith(os.path.realpath(SCRIPTS) + os.sep):
        return jsonify({"ok": False, "message": "Chemin invalide."}), 400
    com = "REM " if ext == ".bat" else ("-- " if ext == ".sql" else ("// " if ext in (".js", ".c", ".cpp", ".h", ".java", ".php", ".rs", ".go") else "# "))
    en_tete = []
    if desc:
        en_tete.append(f"{com}Description: {desc}")
    if mcles:
        en_tete.append(f"{com}Mots-cles: {mcles}")
    contenu_final = ("\n".join(en_tete) + "\n" + code.strip() + "\n") if en_tete else (code.strip() + "\n")
    with VERROU:
        with open(cible, "w", encoding="utf-8") as f:
            f.write(contenu_final)
    charger_index()
    return jsonify({"ok": True, "message": f"Enregistre dans mes_scripts/automatisation/{nom} (index mis a jour)."})

@app.route("/ask", methods=["POST"])
def ask():
    question = request.form.get("question", "").strip()
    mode = request.form.get("mode", "auto")
    utiliser = request.form.get("dossiers") == "1"
    frais = request.form.get("frais") == "1"
    mode_prog = (mode == "programme")

    def flux():
        if not question:
            return
        sig = charger_index()
        cle = (normaliser(question).strip(), mode, utiliser, sig)
        if not frais:
            with VERROU:
                if cle in MEMOIRE:
                    yield MEMOIRE[cle]
                    return
        feedback = charger_feedback()
        contexte = construire_contexte(question, feedback, mode_prog=mode_prog) if utiliser else ""
        if contexte:
            demande = "Exemples et methodes de tes dossiers :\n" + contexte + "\n\nDemande : " + question
        else:
            demande = question
        corps = json.dumps({
            "messages": [{"role": "system", "content": SYSTEME},
                         {"role": "user", "content": demande}],
            "stream": True, "max_tokens": MAX_REPONSE, "temperature": 0.2,
            "top_p": 0.9, "repeat_penalty": 1.12, "cache_prompt": True,
        }).encode("utf-8")
        req = urllib.request.Request(LLM_URL, data=corps,
                                     headers={"Content-Type": "application/json"})
        morceaux_rep = []
        try:
            with urllib.request.urlopen(req, timeout=3600) as rep:
                for ligne in rep:
                    ligne = ligne.decode("utf-8", errors="ignore").strip()
                    if not ligne.startswith("data:"):
                        continue
                    donnee = ligne[5:].strip()
                    if donnee == "[DONE]":
                        break
                    try:
                        delta = json.loads(donnee)["choices"][0]["delta"].get("content")
                    except Exception:
                        continue
                    if delta:
                        morceaux_rep.append(delta)
                        yield delta
            if morceaux_rep:
                with VERROU:
                    MEMOIRE[cle] = "".join(morceaux_rep)
                    while len(MEMOIRE) > TAILLE_MEMOIRE:
                        MEMOIRE.pop(next(iter(MEMOIRE)))
        except Exception:
            yield "[Erreur : le moteur IA ne repond pas. Verifie avec : sudo systemctl status llm_local.service]"

    return Response(stream_with_context(flux()), mimetype="text/plain; charset=utf-8",
                    headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

@app.route("/telecharger")
def telecharger():
    rel = request.args.get("f", "")
    base = os.path.realpath(SCRIPTS)
    chemin = os.path.realpath(os.path.join(base, rel))
    ext = os.path.splitext(chemin)[1].lower()
    if not chemin.startswith(base + os.sep) or ext not in EXT_CODE or not os.path.isfile(chemin):
        abort(404)
    return send_file(chemin, as_attachment=True)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, threaded=True)

EOF

# Mode depot GitHub : si les fichiers du depot sont a cote du script, on les utilise
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$SRC_DIR" != "$APP_DIR" ]; then
  if [ -f "$SRC_DIR/app/server.py" ]; then
    cp "$SRC_DIR/app/server.py" "$APP_DIR/app/server.py"
  fi
  for d in mes_textes mes_scripts; do
    if [ -d "$SRC_DIR/$d" ]; then
      cp -rn "$SRC_DIR/$d/." "$APP_DIR/$d/"
    fi
  done
fi

if [ -z "$(ls -A "$DOCS_DIR")" ]; then
cat << 'EOF' > "$DOCS_DIR/bienvenue.txt"
Ce dossier sert a cultiver votre IA locale. Ajoutez ici vos propres fichiers texte (.txt ou .md) sur l'histoire, l'informatique ou la culture generale.

Pour de meilleurs resultats, separez chaque idee ou paragraphe par une ligne vide. L'IA lira automatiquement tous les fichiers du dossier a chaque nouvelle question.
EOF
fi

echo "=== Scripts d'exemple (seulement si le dossier est vide) ==="
if [ -z "$(ls -A "$SCRIPTS_DIR")" ]; then
mkdir -p "$SCRIPTS_DIR/linux" "$SCRIPTS_DIR/python" "$SCRIPTS_DIR/automatisation"

cat << 'SCRIPT1' > "$SCRIPTS_DIR/linux/sauvegarde_dossier.sh"
#!/bin/bash
# Description: Sauvegarder un dossier dans une archive datee (.tar.gz)
# Mots-cles: sauvegarde backup archive tar compresser dossier copie
SRC="${1:-$HOME/Documents}"
DEST="${2:-$HOME/sauvegardes}"
mkdir -p "$DEST"
FICHIER="$DEST/sauvegarde_$(date +%Y-%m-%d_%H%M).tar.gz"
tar -czf "$FICHIER" -C "$(dirname "$SRC")" "$(basename "$SRC")"
echo "Sauvegarde creee : $FICHIER"
SCRIPT1

cat << 'SCRIPT2' > "$SCRIPTS_DIR/linux/gros_fichiers.sh"
#!/bin/bash
# Description: Lister les 20 plus gros fichiers d'un dossier
# Mots-cles: espace disque gros fichiers taille nettoyer liberer place
DOSSIER="${1:-$HOME}"
find "$DOSSIER" -type f -printf '%s %p\n' 2>/dev/null | sort -nr | head -20 | \
  awk '{ taille=$1; $1=""; printf "%.1f Mo  %s\n", taille/1048576, $0 }'
SCRIPT2

cat << 'SCRIPT3' > "$SCRIPTS_DIR/python/renommer_fichiers.py"
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
SCRIPT3

cat << 'SCRIPT4' > "$SCRIPTS_DIR/python/serveur_web_simple.py"
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
SCRIPT4
fi

echo "=== 4/7 : Service web (demarrage automatique) ==="
sudo tee /etc/systemd/system/ia_locale.service > /dev/null << EOF
[Unit]
Description=Service IA Locale (interface web)
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR/app
ExecStart=/usr/bin/python3 $APP_DIR/app/server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ia_locale.service
sudo systemctl restart ia_locale.service

IP_ADDR=$(hostname -I | awk '{print $1}')
echo "------------------------------------------"
echo "La recherche dans tes dossiers est deja prete :"
echo "http://$IP_ADDR:5000"
echo "Maintenant : installation du moteur IA (long)..."
echo "------------------------------------------"

preparer_swap() {
  [ -f /etc/dphys-swapfile ] || return 1
  sudo dphys-swapfile swapoff || true
  sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile || return 1
  sudo dphys-swapfile setup || return 1
  sudo dphys-swapfile swapon || return 1
}

installer_moteur() {
  if [ ! -d "$LLAMA_DIR" ]; then
    git clone --depth 1 https://github.com/ggml-org/llama.cpp "$LLAMA_DIR" || return 1
  fi
  if [ ! -x "$LLAMA_DIR/build/bin/llama-server" ]; then
    ( cd "$LLAMA_DIR" && \
      cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON -DLLAMA_CURL=OFF && \
      cmake --build build --config Release --target llama-server -j1 ) || return 1
  fi
  [ -x "$LLAMA_DIR/build/bin/llama-server" ] || return 1
  return 0
}

telecharger_modele() {
  mkdir -p "$MODEL_DIR"
  if [ ! -f "$MODEL_FILE" ] || [ "$(stat -c %s "$MODEL_FILE")" -lt 480000000 ]; then
    curl -L -C - --fail -o "$MODEL_FILE" "$MODEL_URL" || return 1
  fi
  [ "$(stat -c %s "$MODEL_FILE")" -ge 480000000 ] || return 1
  return 0
}

creer_service_moteur() {
  sudo tee /etc/systemd/system/llm_local.service > /dev/null << LLMEOF || return 1
[Unit]
Description=Moteur IA local (llama.cpp)
After=network.target

[Service]
User=$USER
ExecStartPre=+/bin/sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true'
ExecStart=$LLAMA_DIR/build/bin/llama-server -m $MODEL_FILE -c 1280 -t 4 -np 1 -b 256 -ub 128 --host 127.0.0.1 --port 8080
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
LLMEOF
  sudo systemctl daemon-reload || return 1
  sudo systemctl enable llm_local.service || return 1
  sudo systemctl restart llm_local.service || return 1
}

echo "=== 5/7 : Memoire d'appoint (swap 1 Go) pour la compilation ==="
preparer_swap || echo "Swap non modifie (ce n'est pas bloquant)."

echo "=== 6/7 : Moteur IA llama.cpp (compilation longue, patience) ==="
if ! installer_moteur; then
  echo "=========================================="
  echo "La compilation de llama.cpp a echoue."
  echo "La recherche dans tes dossiers marche toujours : http://$IP_ADDR:5000"
  echo "Pour reessayer : relance ./install_ia_locale.sh"
  echo "Pour demander de l'aide : copie les 20 dernieres lignes ci-dessus."
  echo "=========================================="
  exit 1
fi

echo "=== 7/7 : Modele IA (environ 490 Mo) et service ==="
if ! telecharger_modele; then
  echo "Telechargement du modele echoue. Verifie internet puis relance le script (il reprend)."
  exit 1
fi
if ! creer_service_moteur; then
  echo "Creation du service du moteur IA echouee."
  exit 1
fi

echo "=========================================="
echo "Installation terminee !"
echo "Scripts a ajouter : $SCRIPTS_DIR"
echo "Textes a ajouter  : $DOCS_DIR"
echo "Ouvre depuis ton PC Windows : http://$IP_ADDR:5000"
echo "(Le moteur IA met 1 a 2 minutes a charger apres le demarrage.)"
echo "=========================================="
