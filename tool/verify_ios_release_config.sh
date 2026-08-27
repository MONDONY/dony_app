#!/usr/bin/env bash
# Vérifie que la configuration Google NATIVE d'iOS appartient au même projet
# Firebase que la configuration DART lue par --dart-define-from-file.
#
# Une divergence ne casse rien à la compilation : elle produit un binaire qui
# s'installe, se lance, et échoue à la connexion Google et à la vérification
# par SMS. C'est exactement ce qui est arrivé à l'IPA 1.0.0+40.
#
# Usage :
#   tool/verify_ios_release_config.sh                    # vérifie les sources
#   tool/verify_ios_release_config.sh build/ios/ipa/Yadony.ipa   # vérifie l'artefact
set -euo pipefail

cd "$(dirname "$0")/.."

SENDER=$(python3 -c "import json;print(json.load(open('env.prod.json'))['FIREBASE_MESSAGING_SENDER_ID'])")
if [ -z "$SENDER" ]; then
  echo "ÉCHEC : FIREBASE_MESSAGING_SENDER_ID absent de env.prod.json"; exit 1
fi
echo "Projet Firebase attendu (côté Dart) : $SENDER"

if [ $# -ge 1 ]; then
  IPA="$1"
  # Le motif doit être ancré sur `Payload/<nom>.app/Info.plist`. Dans unzip, un
  # `*` traverse les `/` : `Payload/*/Info.plist` attrape aussi les quelque 70
  # Info.plist des frameworks et des bundles de confidentialité embarqués, et
  # un `find | head -1` en choisit alors un au hasard, qui ne contient aucun
  # identifiant Google. On lit donc l'index de l'archive, on y sélectionne la
  # seule entrée qui est l'Info.plist de l'application elle-même, et on
  # n'extrait que celle-là.
  # Ne jamais ajouter -m1 à ce grep : sous pipefail, la fermeture anticipée du
  # tube par grep envoie SIGPIPE à unzip tant qu'il n'a pas fini d'écrire tout
  # son index, ce qui a fait échouer ce pipeline une fois sur trois environ.
  ENTRY=$(unzip -Z1 "$IPA" | grep -E '^Payload/[^/]+\.app/Info\.plist$')
  if [ -z "$ENTRY" ]; then
    echo "ÉCHEC : aucun Payload/<app>.app/Info.plist trouvé dans $IPA"
    exit 1
  fi
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  unzip -q -o "$IPA" "$ENTRY" -d "$TMP"
  FOUND=$(plutil -convert xml1 -o - "$TMP/$ENTRY")
  WHERE="l'IPA $IPA"
else
  CFG="ios/Flutter/Release-prod.xcconfig"
  if [ ! -f "$CFG" ]; then
    echo "ÉCHEC : $CFG absent. Le copier depuis $CFG.example et le remplir."; exit 1
  fi
  # Ne garder que les lignes CLE=valeur. Espaces/tabulations tolérés en début
  # de ligne et autour du = : la syntaxe xcconfig les admet, ne pas resserrer
  # ce motif sous prétexte de simplicité. Sans ce filtre, un commentaire du
  # gabarit pourrait citer le bon numéro de projet en toutes lettres
  # (Release-prod.xcconfig.example l.4) sans qu'aucune valeur ne soit
  # réellement renseignée.
  FOUND=$(grep -E '^[[:space:]]*[A-Z_][A-Z0-9_]*[[:space:]]*=' "$CFG" || true)
  WHERE="$CFG"

  # Un gabarit copié tel quel doit échouer explicitement, jamais passer parce
  # qu'un commentaire mentionne le bon projet ailleurs dans le fichier. Le
  # motif d'extraction tolère exactement les mêmes espaces que le filtre
  # ci-dessus, pour que les deux voient toujours les mêmes lignes.
  MISSING=""
  for KEY in GID_CLIENT_ID GID_REVERSED_CLIENT_ID FIREBASE_PHONE_AUTH_URL_SCHEME GOOGLE_MAPS_API_KEY; do
    VALUE=$(sed -n "s/^[[:space:]]*${KEY}[[:space:]]*=[[:space:]]*//p" <<<"$FOUND")
    # Rogner aussi l'espace de fin de ligne, jamais l'intérieur de la valeur :
    # une valeur collée à la main traîne souvent un espace invisible en bout
    # de ligne, et REMPLIR doit rester détectable même suivi d'un espace.
    TRAIL="${VALUE##*[![:space:]]}"
    VALUE="${VALUE%"$TRAIL"}"
    if [ -z "$VALUE" ] || [ "$VALUE" = "REMPLIR" ]; then
      MISSING="$MISSING $KEY"
    fi
  done
  if [ -n "$MISSING" ]; then
    echo "ÉCHEC : $CFG incomplet, valeur manquante ou non renseignée pour :"
    for KEY in $MISSING; do
      echo "  $KEY"
    done
    exit 1
  fi
fi

# Toute valeur Google native (client ID, schéma d'URL) porte le numéro de projet.
if ! grep -q "$SENDER" <<<"$FOUND"; then
  echo "ÉCHEC : $WHERE ne contient pas le projet $SENDER."
  echo "Numéros de projet trouvés :"
  grep -oE '[0-9]{11,13}' <<<"$FOUND" | sort -u | sed 's/^/  /'
  exit 1
fi

# Un autre numéro de projet à onze chiffres ou plus signale un mélange.
OTHERS=$(grep -oE '[0-9]{11,13}' <<<"$FOUND" | sort -u | grep -v "^$SENDER$" || true)
if [ -n "$OTHERS" ]; then
  echo "ÉCHEC : $WHERE mélange plusieurs projets Google."
  echo "$OTHERS" | sed 's/^/  intrus : /'
  exit 1
fi

echo "OK : $WHERE est bien sur le projet $SENDER."
