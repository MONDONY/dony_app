#!/usr/bin/env bash
# Tests du garde-fou Android.
#
# Un garde-fou se juge sur ce qu'il REFUSE, pas sur ce qu'il accepte. Le script
# iOS équivalent a laissé passer quatre faux OK avant d'être correct, chacun
# invisible tant qu'on ne lui soumettait que des cas valides. Ces tests
# soumettent d'abord les cas invalides.
#
# Chaque cas monte une arborescence jetable — un env.prod.json et un
# google-services.json — puis y exécute une copie du script. Aucun secret réel
# n'est nécessaire, et les tests tournent donc partout, y compris en CI.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/verify_android_release_config.sh"
PASS=0
FAIL=0

# Monte une arborescence jetable et rend son chemin.
make_repo() {
  local project="$1" number="$2" env_project="${3:-yadony-prod}" env_sender="${4:-799389399791}"
  local dir; dir=$(mktemp -d)
  mkdir -p "$dir/tool" "$dir/android/app"
  cp "$SCRIPT" "$dir/tool/"
  cat > "$dir/env.prod.json" <<JSON
{ "FIREBASE_PROJECT_ID": "$env_project", "FIREBASE_MESSAGING_SENDER_ID": "$env_sender" }
JSON
  if [ "$project" != "__none__" ]; then
    cat > "$dir/android/app/google-services.json" <<JSON
{ "project_info": { "project_id": "$project", "project_number": "$number" } }
JSON
  fi
  echo "$dir"
}

check() {
  local label="$1" expected="$2" dir="$3"
  local out code
  out=$("$dir/tool/verify_android_release_config.sh" 2>&1); code=$?
  if [ "$code" -eq "$expected" ]; then
    echo "  ok   $label (code $code)"; PASS=$((PASS + 1))
  else
    echo "  ÉCHEC $label : attendu $expected, obtenu $code"
    echo "$out" | sed 's/^/         /'
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$dir"
}

echo "Garde-fou Android — ce qu'il doit REFUSER :"
check "projet de staging au lieu de production" 1 "$(make_repo yadony-f1f0f 917070267063)"
check "bon nom de projet, mauvais numéro"        1 "$(make_repo yadony-prod 917070267063)"
check "google-services.json absent"              1 "$(make_repo __none__ '')"
check "env.prod.json au gabarit"                 1 "$(make_repo yadony-prod 799389399791 your-firebase-project-id 799389399791)"
check "sender non numérique dans env.prod.json"  1 "$(make_repo yadony-prod 799389399791 yadony-prod your-messaging-sender-id)"

# Le cas le plus vicieux : le BON identifiant est présent, donc un contrôle par
# simple présence passerait. C'est un fichier bricolé à la main, ou fusionné
# depuis deux projets.
mixed=$(mktemp -d); mkdir -p "$mixed/tool" "$mixed/android/app"; cp "$SCRIPT" "$mixed/tool/"
cat > "$mixed/env.prod.json" <<'JSON'
{ "FIREBASE_PROJECT_ID": "yadony-prod", "FIREBASE_MESSAGING_SENDER_ID": "799389399791" }
JSON
cat > "$mixed/android/app/google-services.json" <<'JSON'
{ "project_info": { "project_id": "yadony-prod", "project_number": "799389399791 917070267063" } }
JSON
check "mélange de deux projets, le bon inclus" 1 "$mixed"

# Numéro de projet ABSENT : le nom est bon et aucun intrus n'est présent, donc
# ni la comparaison de nom ni la détection de mélange ne peuvent fâcher. Seul le
# contrôle dédié au numéro attrape ce cas — et sans ce test, ce contrôle serait
# mort sans que rien ne le signale.
noNumber=$(mktemp -d); mkdir -p "$noNumber/tool" "$noNumber/android/app"; cp "$SCRIPT" "$noNumber/tool/"
cat > "$noNumber/env.prod.json" <<'JSON'
{ "FIREBASE_PROJECT_ID": "yadony-prod", "FIREBASE_MESSAGING_SENDER_ID": "799389399791" }
JSON
cat > "$noNumber/android/app/google-services.json" <<'JSON'
{ "project_info": { "project_id": "yadony-prod" } }
JSON
check "numéro de projet absent du fichier natif" 1 "$noNumber"

echo "Garde-fou Android — ce qu'il doit ACCEPTER :"
check "production cohérente" 0 "$(make_repo yadony-prod 799389399791)"

echo ""
echo "$PASS réussis, $FAIL échoués"
[ "$FAIL" -eq 0 ]
