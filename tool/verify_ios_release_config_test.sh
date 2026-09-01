#!/usr/bin/env bash
# Tests du garde-fou iOS (mode sources).
#
# Un garde-fou se juge sur ce qu'il REFUSE. Depuis que le script lit
# l'environnement Dart réellement compilé (DART_DEFINES transmis par Flutter à
# Xcode), le cas le plus important est le croisement : config native staging
# sous un build prod, et l'inverse — les deux doivent échouer. Sans DART_DEFINES
# (vérification à la main), env.prod.json fait autorité, sauf YADONY_ENV_FILE.
#
# Chaque cas monte une arborescence jetable et y exécute une copie du script.
# Aucun secret réel n'est nécessaire.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/verify_ios_release_config.sh"
PASS=0
FAIL=0
PROD=799389399791
STAGING=917070267063

# Encode « CLE=VALEUR » comme Flutter le fait pour DART_DEFINES.
define() { printf '%s' "$1" | base64 | tr -d '\n'; }

# Monte une arborescence jetable : env.prod.json (+ env.staging.json) et un
# Release-prod.xcconfig portant le numéro de projet demandé.
make_repo() {
  local native="$1" env_sender="${2:-$PROD}"
  local dir; dir=$(mktemp -d)
  mkdir -p "$dir/tool" "$dir/ios/Flutter"
  cp "$SCRIPT" "$dir/tool/"
  cat > "$dir/env.prod.json" <<JSON
{ "FIREBASE_PROJECT_ID": "yadony-prod", "FIREBASE_MESSAGING_SENDER_ID": "$env_sender" }
JSON
  cat > "$dir/env.staging.json" <<JSON
{ "FIREBASE_PROJECT_ID": "yadony-f1f0f", "FIREBASE_MESSAGING_SENDER_ID": "$STAGING" }
JSON
  if [ "$native" != "__none__" ]; then
    cat > "$dir/ios/Flutter/Release-prod.xcconfig" <<CFG
GID_CLIENT_ID=$native-abc.apps.googleusercontent.com
GID_REVERSED_CLIENT_ID=com.googleusercontent.apps.$native-abc
FIREBASE_PHONE_AUTH_URL_SCHEME=app-1-$native-ios-deadbeef
GOOGLE_MAPS_API_KEY=AIzaFake
CFG
  fi
  echo "$dir"
}

# check <libellé> <code attendu> <dir> [VAR=valeur ...]
check() {
  local label="$1" expected="$2" dir="$3"; shift 3
  local out code
  out=$(env "$@" "$dir/tool/verify_ios_release_config.sh" 2>&1); code=$?
  if [ "$code" -eq "$expected" ]; then
    echo "  ok   $label (code $code)"; PASS=$((PASS + 1))
  else
    echo "  ÉCHEC $label : attendu $expected, obtenu $code"
    echo "$out" | sed 's/^/         /'
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$dir"
}

echo "Garde-fou iOS — ce qu'il doit REFUSER :"
check "config native staging sous env.prod.json (à la main)" 1 "$(make_repo $STAGING)"
check "config native staging sous un build PROD (DART_DEFINES)" 1 "$(make_repo $STAGING)" \
  DART_DEFINES="$(define ENVIRONMENT=production),$(define FIREBASE_MESSAGING_SENDER_ID=$PROD)"
check "config native prod sous un build STAGING (DART_DEFINES)" 1 "$(make_repo $PROD)" \
  DART_DEFINES="$(define FIREBASE_MESSAGING_SENDER_ID=$STAGING)"
check "Release-prod.xcconfig absent" 1 "$(make_repo __none__)"
check "sender non numérique dans env.prod.json" 1 "$(make_repo $PROD your-messaging-sender-id)"
check "DART_DEFINES sans sender ET env.prod.json au gabarit" 1 "$(make_repo $PROD your-messaging-sender-id)" \
  DART_DEFINES="$(define ENVIRONMENT=production)"

# Gabarit copié tel quel : le numéro est cité dans un commentaire, aucune valeur.
tpl=$(mktemp -d); mkdir -p "$tpl/tool" "$tpl/ios/Flutter"; cp "$SCRIPT" "$tpl/tool/"
cat > "$tpl/env.prod.json" <<JSON
{ "FIREBASE_PROJECT_ID": "yadony-prod", "FIREBASE_MESSAGING_SENDER_ID": "$PROD" }
JSON
cat > "$tpl/ios/Flutter/Release-prod.xcconfig" <<CFG
// valeurs du projet yadony-prod ($PROD)
GID_CLIENT_ID=REMPLIR
GID_REVERSED_CLIENT_ID=REMPLIR
FIREBASE_PHONE_AUTH_URL_SCHEME=REMPLIR
GOOGLE_MAPS_API_KEY=REMPLIR
CFG
check "gabarit non rempli, bon numéro en commentaire" 1 "$tpl"

# Mélange : le bon numéro est présent, un intrus aussi.
mixed=$(mktemp -d); mkdir -p "$mixed/tool" "$mixed/ios/Flutter"; cp "$SCRIPT" "$mixed/tool/"
cat > "$mixed/env.prod.json" <<JSON
{ "FIREBASE_PROJECT_ID": "yadony-prod", "FIREBASE_MESSAGING_SENDER_ID": "$PROD" }
JSON
cat > "$mixed/ios/Flutter/Release-prod.xcconfig" <<CFG
GID_CLIENT_ID=$PROD-abc.apps.googleusercontent.com
GID_REVERSED_CLIENT_ID=com.googleusercontent.apps.$STAGING-abc
FIREBASE_PHONE_AUTH_URL_SCHEME=app-1-$PROD-ios-deadbeef
GOOGLE_MAPS_API_KEY=AIzaFake
CFG
check "mélange de deux projets, le bon inclus" 1 "$mixed"

echo "Garde-fou iOS — ce qu'il doit ACCEPTER :"
check "production cohérente (à la main)" 0 "$(make_repo $PROD)"
check "production cohérente sous un build PROD (DART_DEFINES)" 0 "$(make_repo $PROD)" \
  DART_DEFINES="$(define FIREBASE_MESSAGING_SENDER_ID=$PROD)"
check "staging cohérent sous un build STAGING (DART_DEFINES)" 0 "$(make_repo $STAGING)" \
  DART_DEFINES="$(define API_BASE_URL=https://api-staging.example),$(define FIREBASE_MESSAGING_SENDER_ID=$STAGING)"
check "staging cohérent à la main via YADONY_ENV_FILE" 0 "$(make_repo $STAGING)" \
  YADONY_ENV_FILE=env.staging.json

echo ""
echo "$PASS réussis, $FAIL échoués"
[ "$FAIL" -eq 0 ]
