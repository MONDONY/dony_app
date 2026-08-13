# Build IPA staging → TestFlight

Procédure pour générer un `.ipa` staging et le déployer sur TestFlight via Transporter.

## 1. Bump le build number

Dans `pubspec.yaml`, incrémenter le numéro après le `+` (le `1.0.0` avant ne bouge pas) :

```yaml
version: 1.0.0+15   # +1 par rapport au précédent
```

**Toujours vérifier le dernier build déjà présent sur TestFlight/App Store Connect avant de choisir le numéro** — un build number déjà utilisé est rejeté à l'upload.

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
