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
FIREBASE_PHONE_AUTH_URL_SCHEME=<GOOGLE_APP_ID du même fichier, points → tirets>
GOOGLE_MAPS_API_KEY=<GOOGLE_MAPS_API_KEY de env.staging.json>
```

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
