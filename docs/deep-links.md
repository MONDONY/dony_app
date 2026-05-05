# Deep Links — Dony App

## Phase actuelle : custom scheme `dony://` (dev / local)

Le schème personnalisé `dony://` est utilisé pour les redirections locales et de développement.
Il est déclaré dans AndroidManifest.xml (intent-filter) et dans Info.plist (CFBundleURLTypes).
Le package [`app_links`](https://pub.dev/packages/app_links) intercepte les URIs entrantes et
les transmet à GoRouter via `_DonyAppState._handleDeepLink`.

### Routes actives

| URI deep link                          | Route GoRouter                   | Écran                              |
|----------------------------------------|----------------------------------|------------------------------------|
| `dony://stripe/onboarding/complete`    | `/stripe/onboarding/complete`    | Placeholder (PR 4b implémentera l'écran final) |
| `dony://stripe/onboarding/refresh`    | `/stripe/onboarding/refresh`     | Placeholder (PR 4b implémentera l'écran final) |

### Flux technique

```
Stripe redirige vers dony://stripe/onboarding/complete
          ↓
app_links.uriLinkStream émet l'URI
          ↓
_DonyAppState._handleDeepLink(uri)
  → construit routePath = '/' + uri.host + uri.path
  → appRouter.go('/stripe/onboarding/complete')
          ↓
GoRouter route vers le bon écran
```

### Validation du schème

- Android : `android:scheme="dony"` dans deux `<intent-filter>` séparés (un par path)
- iOS : `CFBundleURLSchemes = ["dony"]` dans `CFBundleURLTypes`
- Test manuel : `adb shell am start -a android.intent.action.VIEW -d "dony://stripe/onboarding/complete"`

---

## Phase future (avant mise en production) : Universal Links HTTPS

Avant la mise en production, migrer vers Universal Links (iOS) et App Links (Android) avec le
schème HTTPS pour une expérience utilisateur optimale et pour satisfaire les exigences des stores.

### Checklist de migration

- [ ] **Domaine** — acheter/confirmer le domaine de production (ex. `dony.app`)
- [ ] **HTTPS** — configurer le certificat TLS sur le serveur de production
- [ ] **Android App Links** — déployer `/.well-known/assetlinks.json` sur le domaine :
  ```json
  [{
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.dony.app",
      "sha256_cert_fingerprints": ["<FINGERPRINT>"]
    }
  }]
  ```
- [ ] **iOS Universal Links** — déployer `/.well-known/apple-app-site-association` :
  ```json
  {
    "applinks": {
      "apps": [],
      "details": [{
        "appID": "<TEAM_ID>.com.dony.app",
        "paths": ["/stripe/onboarding/*"]
      }]
    }
  }
  ```
- [ ] **Backend** (`application.yml`) — mettre à jour `stripe.return-url` et `stripe.refresh-url`
  pour utiliser `https://dony.app/stripe/onboarding/complete` (et `/refresh`)
- [ ] **iOS** — ajouter Associated Domains dans `Runner.entitlements` :
  ```xml
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:dony.app</string>
  </array>
  ```
- [ ] **Android** — modifier les `<intent-filter>` dans `AndroidManifest.xml` :
  - Remplacer `android:scheme="dony"` par `android:scheme="https"`
  - Ajouter `android:host="dony.app"`
  - Ajouter `android:autoVerify="true"` sur chaque intent-filter
- [ ] **Tests** — vérifier les deux routes avec les URLs HTTPS sur device réel
- [ ] **Supprimer** le schème `dony://` de `Info.plist` et `AndroidManifest.xml`
  (ou conserver pour le développement uniquement via build flavors)
