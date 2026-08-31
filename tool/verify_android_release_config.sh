#!/usr/bin/env bash
# Vérifie que la configuration Google NATIVE d'Android appartient au même projet
# Firebase que la configuration DART lue par --dart-define-from-file.
#
# Le pendant Android de verify_ios_release_config.sh, et pour la même raison :
# une divergence ne casse rien à la compilation. Elle produit un binaire qui
# s'installe, se lance, et échoue à la connexion Google et à la vérification par
# SMS une fois publié. L'IPA 1.0.0+40 est partie ainsi ; côté Android rien
# n'empêchait que ça se reproduise.
#
# Le fichier google-services.json est gitignoré et s'échange à la main : l'état
# de l'environnement natif est donc invisible, et ce script est le seul moyen de
# le rendre visible avant qu'un artefact ne parte.
#
# Usage :
#   tool/verify_android_release_config.sh                       # vérifie les sources
#   tool/verify_android_release_config.sh build/app/outputs/bundle/release/app-release.aab
set -euo pipefail

cd "$(dirname "$0")/.."

# `read ... <<<"$(cmd)"` PERD le code de sortie de la substitution : c'est `read`
# dont le statut compte, et il vaut 0 des qu'il a lu une ligne, fut-elle vide.
# Le script affichait alors « ÉCHEC » et rendait 0 — précisément le faux OK que
# ce garde-fou existe pour empêcher. On capture, on teste, puis on découpe.
if ! EXPECTED=$(python3 - <<'PY'
import json, sys
try:
    env = json.load(open("env.prod.json"))
except FileNotFoundError:
    sys.exit("ÉCHEC : env.prod.json absent. Le copier depuis env.prod.json.example et le remplir.")
project = env.get("FIREBASE_PROJECT_ID", "").strip()
sender = env.get("FIREBASE_MESSAGING_SENDER_ID", "").strip()
# Un gabarit copié tel quel porte des valeurs d'exemple : les refuser
# explicitement plutôt que de comparer le natif à une chaîne factice, ce qui
# ferait passer le contrôle pour deux mauvaises raisons qui s'annulent.
if not project or project.startswith("your-"):
    sys.exit("ÉCHEC : FIREBASE_PROJECT_ID absent ou non renseigné dans env.prod.json")
if not sender or not sender.isdigit():
    sys.exit("ÉCHEC : FIREBASE_MESSAGING_SENDER_ID absent ou non numérique dans env.prod.json")
print(project, sender)
PY
); then
  echo "$EXPECTED"
  exit 1
fi
read -r EXPECTED_ID EXPECTED_NUMBER <<<"$EXPECTED"

echo "Projet Firebase attendu (côté Dart) : $EXPECTED_ID ($EXPECTED_NUMBER)"

if [ $# -ge 1 ]; then
  AAB="$1"
  if [ ! -f "$AAB" ]; then
    echo "ÉCHEC : $AAB introuvable."; exit 1
  fi
  # Les valeurs de google-services.json sont compilées en ressources string
  # (project_id, gcm_defaultSenderId, google_app_id) et atterrissent dans le
  # protobuf des ressources du module de base. On lit les chaînes plutôt que de
  # décoder le protobuf : aucune dépendance à installer, et le seul besoin est
  # de savoir QUELS identifiants sont présents.
  FOUND=$(unzip -p "$AAB" base/resources.pb | strings)
  WHERE="l'AAB $AAB"
else
  CFG="android/app/google-services.json"
  if [ ! -f "$CFG" ]; then
    echo "ÉCHEC : $CFG absent."
    echo "Le télécharger depuis la console Firebase du projet $EXPECTED_ID."
    exit 1
  fi
  FOUND=$(python3 - "$CFG" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
info = data.get("project_info", {})
# N'imprimer que les deux identifiants qui décident, pas le fichier entier :
# une clé d'API contient des suites de chiffres qui pollueraient la détection
# de mélange plus bas.
print(info.get("project_id", ""))
print(info.get("project_number", ""))
PY
)
  WHERE="$CFG"
fi

if ! grep -qF "$EXPECTED_ID" <<<"$FOUND"; then
  echo "ÉCHEC : $WHERE n'est pas sur le projet $EXPECTED_ID."
  echo "Projets Firebase trouvés :"
  grep -oE 'yadony-[a-z0-9]+' <<<"$FOUND" | sort -u | sed 's/^/  /'
  echo "Numéros de projet trouvés :"
  grep -oE '\b[0-9]{11,13}\b' <<<"$FOUND" | sort -u | sed 's/^/  /'
  exit 1
fi

if ! grep -qF "$EXPECTED_NUMBER" <<<"$FOUND"; then
  echo "ÉCHEC : $WHERE porte le bon nom de projet mais pas le numéro $EXPECTED_NUMBER."
  echo "Un fichier renommé à la main, ou copié du mauvais projet."
  exit 1
fi

# Un autre numéro de projet à onze chiffres ou plus signale un mélange : c'est
# le cas le plus vicieux, parce que le bon identifiant EST présent et qu'un
# contrôle par simple présence passerait.
OTHERS=$(grep -oE '\b[0-9]{11,13}\b' <<<"$FOUND" | sort -u | grep -vF "$EXPECTED_NUMBER" || true)
if [ -n "$OTHERS" ]; then
  echo "ÉCHEC : $WHERE mélange plusieurs projets Google."
  echo "$OTHERS" | sed 's/^/  intrus : /'
  exit 1
fi

echo "OK : $WHERE est bien sur le projet $EXPECTED_ID ($EXPECTED_NUMBER)."
