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

## Secrets à créer (Settings → Secrets → Actions)

Déjà utilisés par `build-release.yml` : `FLUTTER_API_BASE_URL`,
`FLUTTER_FIREBASE_PROJECT_ID`, `FLUTTER_FIREBASE_MESSAGING_SENDER_ID`,
`FLUTTER_FIREBASE_STORAGE_BUCKET`, `FLUTTER_FIREBASE_ANDROID_API_KEY`,
`FLUTTER_FIREBASE_ANDROID_APP_ID`, `FLUTTER_FIREBASE_IOS_API_KEY`,
`FLUTTER_FIREBASE_IOS_APP_ID`, `FLUTTER_STRIPE_PUBLISHABLE_KEY`,
`FLUTTER_SENTRY_DSN`, `FLUTTER_GOOGLE_MAPS_API_KEY` (clé iOS),
`FLUTTER_GOOGLE_MAPS_ANDROID_API_KEY`, `FLUTTER_POSTHOG_API_KEY`,
`GOOGLE_SERVICES_JSON` (= `secrets/prod/google-services.json`).
Valeurs prod : voir `env.prod.json` local.

Nouveaux :

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i secrets/prod/yadony-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` | `android/key.properties` (alias `upload`) |
| `PLAY_SERVICE_ACCOUNT_JSON` | `secrets/prod/yadony-prod-398bc07be442.json` (compte `play-upload-prod`) |
| `IOS_GOOGLE_SERVICE_INFO_PLIST` | `secrets/prod/GoogleService-Info-4.plist` |
| `IOS_RELEASE_PROD_XCCONFIG` | `secrets/prod/Release-prod.xcconfig` |
| `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD` | certificat « Apple Distribution » exporté du Trousseau en .p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | profil App Store `com.yadony.yadony` (`base64 -i profil.mobileprovision`) |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | clé API App Store Connect (App Manager), contenu du .p8 |

Exemple : `gh secret set ANDROID_KEYSTORE_BASE64 --repo MONDONY/dony_app < <(base64 -i secrets/prod/yadony-upload.jks)`

## Pièges

- Profil de distribution : il expire (le dernier, « Yadony AppStore 146 », au 2027-08-07). Régénérer et remplacer le secret avant.
- Le build prod part vers TestFlight même si le back prod n'est pas déployé : vérifier la PR jumelle avant de promouvoir un build.
- Le projet Xcode est en signature automatique ; la CI archive en signature manuelle par surcharge de réglages, rien à changer en local.

## Sécurité

Le job `prepare` n'accepte que : un lancement manuel, ou une CI verte issue d'un
**push sur main de ce dépôt** (pas d'un fork). Recommandé en plus : déclarer
les secrets de signature dans un Environment GitHub « stores » limité à la
branche main, avec relecteur obligatoire si tu veux un go avant chaque envoi.
