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

# La clé Google Maps du manifest natif est résolue par build.gradle.kts :
# GOOGLE_MAPS_ANDROID_API_KEY (variable, puis fichier passé à
# --dart-define-from-file, puis env.dev.json), avec repli sur
# GOOGLE_MAPS_API_KEY hors production seulement. La tâche Gradle qui lance ce
# script lui exporte la clé retenue dans GOOGLE_MAPS_ANDROID_API_KEY : c'est
# elle qui est contrôlée. Avant la lecture des dart-defines, un build lancé avec
# env.staging.json recevait la clé de env.dev.json, ou une chaîne vide (builds
# 1.0.0+78 à +83, aucune carte).
#
# Deuxième panne, même symptôme (build 143, Sentry YADONY-FLUTTER-PROD-1T) : le
# manifest portait une clé, mais celle d'iOS (GOOGLE_MAPS_API_KEY de
# env.prod.json, yadony-prod-ios, restreinte au bundle iOS). Le SDK Android la
# refuse et la carte reste vide. Un contrôle de simple présence passait. La clé
# du manifest doit donc aussi DIFFÉRER de la clé iOS de env.prod.json.
#
# Aucune clé n'est jamais affichée : seuls des messages fixes sortent d'ici.
IOS_MAPS_KEY=$(python3 - <<'PY2'
import json
print(json.load(open("env.prod.json")).get("GOOGLE_MAPS_API_KEY", "").strip())
PY2
)

if [ $# -ge 1 ]; then
  # Seule la valeur injectée dans le manifest prouve quelque chose : la clé vue
  # par Dart est compilée dans le binaire et reste correcte même quand le natif
  # est vide, ce qui est exactement le cas qui a échappé jusqu'ici.
  #
  # `... | strings | grep -q` sous pipefail rend un code NON NUL quand la clé est
  # présente : grep -q sort à la première correspondance, ferme le tube, et
  # strings meurt d'un SIGPIPE dont pipefail fait le statut du pipeline. Le
  # garde-fou refusait alors les artefacts valides. Même remède que pour `read`
  # plus haut : on capture, puis on teste.
  MANIFEST_STRINGS=$(unzip -p "$AAB" base/manifest/AndroidManifest.xml | strings)
  # LC_ALL=C : le manifest est du protobuf, la ligne de la clé peut porter des
  # octets non UTF-8 ; sous une locale UTF-8, grep -o de macOS n'en extrait
  # alors rien (constaté sur l'AAB 143) et le garde-fou croirait la clé absente.
  MAPS_KEY=$(LC_ALL=C grep -oE 'AIza[0-9A-Za-z_-]{35}' <<<"$MANIFEST_STRINGS" | head -n 1 || true)
  if [ -z "$MAPS_KEY" ]; then
    echo "ÉCHEC : $WHERE n'embarque aucune clé Google Maps dans son manifest."
    echo "Les cartes seront blanches. Rebâtir avec GOOGLE_MAPS_ANDROID_API_KEY renseignée."
    exit 1
  fi
else
  MAPS_KEY="${GOOGLE_MAPS_ANDROID_API_KEY:-}"
  if [ -z "$MAPS_KEY" ] && [ -f env.dev.json ]; then
    MAPS_KEY=$(python3 - <<'PY2'
import json
env = json.load(open("env.dev.json"))
print((env.get("GOOGLE_MAPS_ANDROID_API_KEY") or env.get("GOOGLE_MAPS_API_KEY") or "").strip())
PY2
)
  fi
  case "$MAPS_KEY" in
    AIza*) ;;
    "")
      echo "ÉCHEC : aucune clé Google Maps Android pour le manifest natif."
      echo "Renseigner GOOGLE_MAPS_ANDROID_API_KEY (env.prod.json ou variable d'environnement)."
      exit 1
      ;;
    *)
      echo "ÉCHEC : la clé Google Maps ne commence pas par AIza (gabarit non rempli ?)."
      exit 1
      ;;
  esac
fi

if [ -n "$IOS_MAPS_KEY" ] && [ "$MAPS_KEY" = "$IOS_MAPS_KEY" ]; then
  echo "ÉCHEC : la clé Google Maps du manifest Android est la clé iOS (GOOGLE_MAPS_API_KEY de env.prod.json)."
  echo "Restreinte au bundle iOS, le SDK Maps Android la refuse : carte vide (build 143, YADONY-FLUTTER-PROD-1T)."
  echo "Renseigner GOOGLE_MAPS_ANDROID_API_KEY avec la clé yadony-prod-android."
  exit 1
fi

# Contrôle en ligne, facultatif : si gcloud est installé et authentifié, la clé
# doit porter une restriction Android. Hors-ligne, ou sans droit sur le projet,
# il est sauté sans échec : le contrôle ci-dessus suffit à refuser le cas du
# build 143. VERIFY_MAPS_KEY_GCLOUD=0 le désactive (tests, CI).
if [ "${VERIFY_MAPS_KEY_GCLOUD:-1}" != "0" ] && command -v gcloud >/dev/null 2>&1 \
   && gcloud auth print-access-token >/dev/null 2>&1; then
  KEY_NAME=$(gcloud services api-keys lookup "$MAPS_KEY" --format='value(name)' 2>/dev/null || true)
  if [ -z "$KEY_NAME" ]; then
    echo "AVERTISSEMENT : gcloud ne retrouve pas la clé Maps (projet inaccessible ?), contrôle de restriction sauté."
  else
    RESTRICTION=$(gcloud services api-keys describe "$KEY_NAME" --format=json 2>/dev/null | python3 -c '
import json, sys
try:
    r = json.load(sys.stdin).get("restrictions", {})
except ValueError:
    print("inconnue"); sys.exit()
print("android" if "androidKeyRestrictions" in r else ",".join(k for k in r if k.endswith("KeyRestrictions")) or "aucune")
' || echo inconnue)
    case "$RESTRICTION" in
      android) echo "OK : la clé Maps du manifest porte une restriction Android (gcloud)." ;;
      inconnue) echo "AVERTISSEMENT : restriction de la clé Maps illisible via gcloud, contrôle sauté." ;;
      aucune) echo "AVERTISSEMENT : la clé Maps du manifest n'a aucune restriction d'application (acceptée par Android, mais à restreindre)." ;;
      *)
        echo "ÉCHEC : la clé Maps du manifest n'est pas restreinte Android (restriction : $RESTRICTION)."
        echo "Le SDK Maps Android la refusera. Utiliser la clé yadony-prod-android."
        exit 1
        ;;
    esac
  fi
fi

echo "OK : clé Google Maps Android présente pour le manifest natif, distincte de la clé iOS."
