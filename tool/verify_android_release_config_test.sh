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
  # La clé Maps du manifest natif se lit ici, pas dans env.prod.json. Sans elle
  # tous les cas « doit accepter » échoueraient pour une raison sans rapport.
  cat > "$dir/env.dev.json" <<'JSON'
{ "GOOGLE_MAPS_API_KEY": "AIzaSyFAKEfakeFAKEfakeFAKEfakeFAKEfake0" }
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
  out=$(env -u GOOGLE_MAPS_API_KEY "$dir/tool/verify_android_release_config.sh" 2>&1); code=$?
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

# Clé Maps : la panne qui a produit les builds 1.0.0+78 à +83. Le natif reçoit
# une chaîne vide, tout le reste est cohérent, et l'appli se lance sans carte.
noMaps=$(make_repo yadony-prod 799389399791); rm "$noMaps/env.dev.json"
check "aucune clé Maps (ni variable, ni env.dev.json)" 1 "$noMaps"

emptyMaps=$(make_repo yadony-prod 799389399791)
cat > "$emptyMaps/env.dev.json" <<'JSON'
{ "GOOGLE_MAPS_API_KEY": "" }
JSON
check "clé Maps vide dans env.dev.json" 1 "$emptyMaps"

tplMaps=$(make_repo yadony-prod 799389399791)
cat > "$tplMaps/env.dev.json" <<'JSON'
{ "GOOGLE_MAPS_API_KEY": "your-google-maps-api-key" }
JSON
check "clé Maps au gabarit non rempli" 1 "$tplMaps"

echo "Garde-fou Android — ce qu'il doit ACCEPTER :"
check "production cohérente" 0 "$(make_repo yadony-prod 799389399791)"

# La variable d'environnement prime sur env.dev.json : c'est la voie de CI et
# celle des builds à la main. Sans ce test, le garde-fou pourrait n'accepter que
# le fichier et casser la release.
envKeyDir=$(make_repo yadony-prod 799389399791); rm "$envKeyDir/env.dev.json"
envOut=$(GOOGLE_MAPS_API_KEY=AIzaSyFAKEfakeFAKEfakeFAKEfakeFAKEfake0 \
  "$envKeyDir/tool/verify_android_release_config.sh" 2>&1); envCode=$?
if [ "$envCode" -eq 0 ]; then
  echo "  ok   clé Maps fournie par la variable d'environnement (code 0)"; PASS=$((PASS + 1))
else
  echo "  ÉCHEC clé Maps fournie par la variable d'environnement : attendu 0, obtenu $envCode"
  echo "$envOut" | sed 's/^/         /'; FAIL=$((FAIL + 1))
fi
rm -rf "$envKeyDir"


# Mode AAB. Il n'avait aucun test, et c'est précisément là qu'un défaut s'est
# glissé : `unzip | strings | grep -q` sous pipefail rend un code non nul QUAND
# la clé est présente (grep -q ferme le tube, strings meurt d'un SIGPIPE), donc
# le garde-fou refusait les artefacts valides. Un cas « doit accepter » sur un
# AAB était le seul moyen de le voir.
echo "Garde-fou Android — mode AAB :"

# Monte un faux bundle : les deux seules entrées que le script lit.
make_aab() {
  local with_key="$1" dir="$2"
  mkdir -p "$dir/base/manifest"
  printf 'yadony-prod\n799389399791\n' > "$dir/base/resources.pb"
  if [ "$with_key" = "with_key" ]; then
    printf 'com.google.android.geo.API_KEY\nAIzaSyFAKEfakeFAKEfakeFAKEfakeFAKEfake0\n' \
      > "$dir/base/manifest/AndroidManifest.xml"
  else
    printf 'com.google.android.geo.API_KEY\n\n' > "$dir/base/manifest/AndroidManifest.xml"
  fi
  (cd "$dir" && zip -qr bundle.aab base)
  echo "$dir/bundle.aab"
}

check_aab() {
  local label="$1" expected="$2" aab="$3" dir="$4"
  local out code
  out=$(cd "$dir" && env -u GOOGLE_MAPS_API_KEY "$dir/tool/verify_android_release_config.sh" "$aab" 2>&1); code=$?
  if [ "$code" -eq "$expected" ]; then
    echo "  ok   $label (code $code)"; PASS=$((PASS + 1))
  else
    echo "  ÉCHEC $label : attendu $expected, obtenu $code"
    echo "$out" | sed 's/^/         /'
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$dir"
}

okAab=$(make_repo yadony-prod 799389399791)
check_aab "AAB avec clé Maps" 0 "$(make_aab with_key "$okAab")" "$okAab"

koAab=$(make_repo yadony-prod 799389399791)
check_aab "AAB sans clé Maps" 1 "$(make_aab no_key "$koAab")" "$koAab"

echo ""
echo "$PASS réussis, $FAIL échoués"
[ "$FAIL" -eq 0 ]
