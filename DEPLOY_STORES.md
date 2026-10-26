# Déploiement automatique vers les stores

`.github/workflows/deploy-stores.yml` : après chaque CI verte sur `main`,
- **iOS** : build prod signé, envoi à **TestFlight** ;
- **Android** : AAB prod signé, envoi à la piste **interne** de Google Play.

La mise en production (review Apple, piste production Play) reste manuelle.
Lancement à la main : Actions → Deploy stores → Run workflow (cases iOS / Android).

Un merge qui ne touche ni `lib/`, `assets/`, `ios/`, `android/` ni `pubspec.*` est ignoré.

## Numéro de build

`tool/next_build_number.py` lit le plus grand numéro déjà envoyé à App Store
Connect et à Google Play (builds manuels compris) et prend ce maximum + 1. iOS
et Android reçoivent donc le même numéro, et un build fait à la main s'intègre
dans la même suite. Si un store ne répond pas, le déploiement échoue : jamais
de numéro inventé.

`BUILD_NUMBER_FLOOR` (workflow, 1008) couvre un angle mort : l'API Apple ne
liste un build qu'une fois son traitement commencé. Le plancher n'a plus à
bouger tant que les stores contiennent des numéros plus grands.

Build manuel : prendre un numéro au-dessus du dernier de la CI.
Le numéro de version (`1.0.0`) vient toujours de `pubspec.yaml`.

Test du script : `cd tool && python3 -m unittest next_build_number_test`.

## Secrets

Deux Environments GitHub, `staging` et `production`, portent chacun les valeurs
propres à l'environnement sous les mêmes noms :
`FLUTTER_*` (API, Firebase, Stripe, Sentry, Maps, PostHog), `GOOGLE_SERVICES_JSON`,
`IOS_GOOGLE_SERVICE_INFO_PLIST`, `IOS_RELEASE_PROD_XCCONFIG`.
Staging n'a pas de `FLUTTER_GOOGLE_MAPS_ANDROID_API_KEY` : Gradle replie sur la clé générale.

Ces noms ne doivent PAS exister au niveau du dépôt : un secret d'environnement
manquant retomberait sinon sur une valeur de production.

Partagés (niveau dépôt, signature et accès aux stores) : `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`,
`PLAY_SERVICE_ACCOUNT_JSON`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
`IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`.

Poser un secret d'environnement : `gh secret set NOM -R MONDONY/dony_app --env staging < fichier`.

## Pièges

- Profil de distribution : il expire (le dernier, « Yadony AppStore 146 », au 2027-08-07). Régénérer et remplacer le secret avant.
- Un build de production lancé à la main part vers TestFlight / Play même si le back prod n'est pas déployé : vérifier la PR jumelle avant de promouvoir un build.
- Staging et production partagent la même fiche (même bundle id) : un build staging apparaît dans les mêmes pistes de test. Le numéro de build dit lequel est lequel seulement par le journal Actions.
- Le projet Xcode est en signature automatique ; la CI archive en signature manuelle par surcharge de réglages, rien à changer en local.

## Sécurité

Le job `prepare` n'accepte que : un lancement manuel, ou une CI verte issue d'un
**push sur main de ce dépôt** (pas d'un fork). Recommandé en plus : déclarer
les secrets de signature dans un Environment GitHub « stores » limité à la
branche main, avec relecteur obligatoire si tu veux un go avant chaque envoi.
