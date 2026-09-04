# Build IPA staging → TestFlight

Procédure pour générer un `.ipa` staging et le déployer sur TestFlight via Transporter.

## 1. Bump le build number

Dans `pubspec.yaml`, incrémenter le numéro après le `+` (le `1.0.0` avant ne bouge pas) :

```yaml
version: 1.0.0+15   # +1 par rapport au précédent
```

**Toujours vérifier le dernier build déjà présent sur TestFlight/App Store Connect avant de choisir le numéro** — un build number déjà utilisé est rejeté à l'upload.

## 1bis. `ios/Flutter/Release-prod.xcconfig` (worktree neuf)

Gitignoré, absent de tout worktree neuf. La phase Xcode « Verify iOS Release
Config » (`tool/verify_ios_release_config.sh`) l'exige pour **tout** build
Release — staging inclus, malgré son nom. Le script est agnostique de
l'environnement : il compare le contenu de ce fichier au projet Firebase
attendu côté Dart (`FIREBASE_MESSAGING_SENDER_ID` de `env.staging.json` ou
`env.prod.json`), donc pour un build **staging** il faut y mettre les
valeurs **staging** (projet `yadony-f1f0f`, sender `917070267063`), pas
celles de prod — malgré ce que dit le gabarit `Release-prod.xcconfig.example`.

Sans lui, l'archive échoue tard (`Command PhaseScriptExecution failed`,
juste avant `Encountered error while archiving for device`) après ~1-2 min
de compilation Swift/ObjC, un signal facile à confondre avec une vraie
erreur de code.

```
GID_CLIENT_ID=<CLIENT_ID de secrets/staging/GoogleService-Info-3.plist>
GID_REVERSED_CLIENT_ID=<REVERSED_CLIENT_ID du même fichier>
FIREBASE_PHONE_AUTH_URL_SCHEME=app-<GOOGLE_APP_ID du même fichier, deux-points → tirets>
GOOGLE_MAPS_API_KEY=<GOOGLE_MAPS_API_KEY de env.staging.json>
```

**`FIREBASE_PHONE_AUTH_URL_SCHEME` a besoin du préfixe `app-`.** Format
Firebase documenté : `app-` + `GOOGLE_APP_ID` (ex. `1:917070267063:ios:xxxx`)
avec les **deux-points** remplacés par des tirets, soit
`app-1-917070267063-ios-xxxx`. Sans le préfixe, le schéma commence par un
chiffre : la compilation et le build passent quand même, mais l'**upload App
Store Connect** rejette avec 409 « URL schemes ... need to begin with an
alphabetic character » (RFC1738) — invisible avant l'upload, jamais détecté
par `tool/verify_ios_release_config.sh` (il vérifie seulement que le numéro
de projet apparaît, pas la forme du schéma).

**`secrets/staging/GoogleService-Info-2.plist` est un piège** : même projet,
mais sans `CLIENT_ID`/`REVERSED_CLIENT_ID` (fichier incomplet, antérieur de
quelques heures à `-3`). Toujours prendre `-3`, vérifiable via `plutil -p`.

Vérifier avant de lancer le build (évite d'attendre l'échec en fin d'archive) :

```bash
YADONY_ENV_FILE=env.staging.json tool/verify_ios_release_config.sh
```

Et sur l'artefact final, une fois généré :

```bash
YADONY_ENV_FILE=env.staging.json tool/verify_ios_release_config.sh build/ios/ipa/Yadony.ipa
```

## 2. Build le .ipa

Depuis la racine de `dony_app/` :

```bash
flutter build ipa --release --dart-define-from-file=env.staging.json
```

- `--release` : build de production (nécessaire pour un `.ipa` valide App Store/TestFlight).
- `env.staging.json` : fichier d'environnement (API_BASE_URL, clés Firebase/Stripe/Sentry, etc. — voir `env.dev.json`/`env.android.json` pour les autres environnements disponibles).

Le build passe par deux phases :
1. `Running Xcode build...` — archive Xcode (peut demander une validation Keychain la première fois : une popup système peut apparaître, cliquer "Toujours autoriser").
2. `Building App Store IPA...` — export signé, re-signature avec le certificat de distribution.

Durée typique : quelques minutes. Le résultat :

```
✓ Built IPA to build/ios/ipa (XX.XMB)
```

Fichier généré : **`build/ios/ipa/Yadony.ipa`**

## 3. Uploader via Transporter

1. Ouvrir l'app **Transporter** (Mac App Store : [apps.apple.com/app/transporter/id1450874784](https://apps.apple.com/us/app/transporter/id1450874784)).
2. Se connecter avec le compte Apple Developer du projet.
3. Glisser-déposer `build/ios/ipa/Yadony.ipa` dans la fenêtre Transporter.
4. Cliquer **Deliver** (ou "Livrer").
5. Attendre la validation + l'upload (barre de progression).

Une fois uploadé, Apple traite le build (quelques minutes à ~1h) avant qu'il apparaisse dans TestFlight (App Store Connect → TestFlight → Builds).

## Alternative en ligne de commande (sans Transporter)

```bash
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/Yadony.ipa \
  --apiKey <API_KEY_ID> \
  --apiIssuer <ISSUER_ID>
```

Nécessite une clé API App Store Connect (Users and Access → Keys, dans App Store Connect).

## Pièges connus

- **Build number déjà utilisé** : App Store Connect rejette l'upload. Toujours bump `pubspec.yaml` avant de builder.
- **Popup Keychain invisible en exécution automatisée** : si le build reste bloqué sans avancer sur `Running Xcode build...` pendant plusieurs minutes, vérifier l'écran du Mac — une popup système "Toujours autoriser" attend peut-être une validation.
- **aps-environment** : le build Release doit utiliser les entitlements de production (`ios/Runner/Runner-Release.entitlements`, `aps-environment=production`) pour que les notifications push fonctionnent une fois l'app fermée. Ne pas pointer `CODE_SIGN_ENTITLEMENTS` de la config Release vers `Runner/Runner.entitlements` (développement).
- **Ne pas lancer `flutter build` en parallèle d'un `flutter run`** — les deux partagent `.dart_tool` et se corrompent mutuellement. Toujours tuer les sessions `flutter run` actives avant un build (`pkill -f "flutter run"`).
- **`FIREBASE_PHONE_AUTH_URL_SCHEME` sans le préfixe `app-`** : le build et l'archive Xcode passent sans erreur, mais l'upload App Store Connect rejette (409 « URL schemes ... need to begin with an alphabetic character », RFC1738 — le schéma commence alors par le chiffre du numéro de projet). Détecté le 2026-09-04 sur le build 50 : la valeur correcte est `app-` + `GOOGLE_APP_ID` avec les deux-points remplacés par des tirets (`app-1-917070267063-ios-xxxx`), pas seulement les deux-points remplacés. Voir la section 1bis ci-dessus.
