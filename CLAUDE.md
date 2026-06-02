# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project: dony Mobile App (Flutter)

P2P marketplace mobile pour la diaspora africaine (transport de colis vers l'Afrique).

**Stack:** Flutter/Dart · flutter_bloc · GoRouter · Dio · Hive · Firebase Auth (Phone) · Stripe · FCM · Sentry  
Min SDK: iOS 14+ / Android 8.0+ (API 26)

---

## Démarrage rapide — Émulateur Android (WSL2)

> L'IP WSL2 change à chaque redémarrage — toujours refaire l'étape 2.  
> `android/app/src/debug/AndroidManifest.xml` autorise déjà le HTTP cleartext en debug.

**1. Démarrer Spring Boot** (garder le terminal ouvert) :
```bash
cd /mnt/c/Users/abou5/Desktop/mon-dony/dony-back
./mvnw spring-boot:run -Dspring.profiles.active=dev
```

**2. Mettre à jour `env.dev.json`** :
```bash
WSL_IP=$(hostname -I | awk '{print $1}') && \
sed -i "s|\"API_BASE_URL\": \"http://[^\"]*\"|\"API_BASE_URL\": \"http://$WSL_IP:8080/api/v1\"|" env.dev.json
```

**3. Lancer Flutter** :
```bash
adb devices  # vérifier l'émulateur
flutter run --dart-define-from-file=env.dev.json -d emulator-5554
```

| Problème | Solution |
|----------|----------|
| `Connection refused` | Refaire étape 2 (IP périmée) ou démarrer Spring Boot (étape 1) |
| `emulator offline` | `adb kill-server && adb start-server` |
| Back ne reçoit rien | Vérifier `server.address=0.0.0.0` dans `application-dev.yml` |
| HTTP bloqué | Vérifier `android/app/src/debug/AndroidManifest.xml` |

---

## Commands

```bash
# Dev
flutter run --dart-define-from-file=env.dev.json [-d <device-id>]
flutter clean && flutter pub get && flutter run --dart-define-from-file=env.dev.json

# Qualité
flutter analyze && dart fix --apply && dart format lib/ test/

# Tests
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Build
flutter build apk --dart-define-from-file=env.prod.json --release
flutter build appbundle --dart-define-from-file=env.prod.json --release

# Code gen
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Architecture (Feature-First)

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart          # GoRouter — TOUTES les routes ici
│   └── theme.dart
├── core/
│   ├── di/injection.dart    # GetIt DI setup
│   ├── network/
│   │   ├── api_client.dart  # Instance Dio unique
│   │   └── auth_interceptor.dart
│   ├── storage/hive_service.dart
│   ├── error/
│   └── constants/
└── features/
    ├── auth/
    ├── kyc/
    ├── matching/
    ├── cancellation/        # DÉDIÉ — jamais dans matching/
    ├── tracking/            # offline_queue.dart (Hive)
    ├── payments/
    ├── notifications/
    ├── disputes/
    └── admin/
```

**Règle absolue :** chaque feature = exactement `bloc/` + `data/` + `presentation/`.  
`data/` contient : `models/`, `repositories/`, `datasources/`.

---

## Core Principles

### 1. State Management — flutter_bloc (JAMAIS setState)

- Events : suffixe `Requested` (`BidCreateRequested`, `TrackingQrScannedRequested`)
- States : sealed class → `Initial`, `Loading`, `Success`/`Authenticated`, `Error`
- Dans les widgets : `BlocConsumer` — `listener` pour navigation/snackbar, `builder` pour l'UI
- DI : `BlocProvider(create: (_) => getIt<XxxBloc>())` groupés dans `MultiBlocProvider`

### 2. Navigation — GoRouter (JAMAIS Navigator.push)

- Toutes les routes dans `lib/app/router.dart`
- Auth guard via `redirect` callback
- `context.go('/home')` · `context.push('/path', extra: data)` · `context.pop()`
- Deep links : `dony://payment/confirm?payment_intent=pi_xxx` · `dony://tracking/scan?bid_id=xxx` · `https://dony.app/tracking/{token}`

### 3. HTTP — Dio + AuthInterceptor (JAMAIS package http)

- Instance unique dans `ApiClient(baseUrl: ...)`
- `AuthInterceptor` injecte automatiquement le Firebase ID token sur chaque requête
- Timeouts : 10 s connect, 30 s receive. Retry avec exponential backoff sur erreurs réseau.

### 4. Environnement

```json
{ "API_BASE_URL": "http://<IP-WSL>:8080/api/v1", "FIREBASE_PROJECT_ID": "dony-dev",
  "STRIPE_PUBLISHABLE_KEY": "pk_test_xxx", "SENTRY_DSN": "..." }
```
Accès : `const x = String.fromEnvironment('API_BASE_URL');`  
Ne jamais hardcoder — toujours `--dart-define-from-file`.

### 5. Dependency Injection — GetIt (JAMAIS instancier directement)

- `registerLazySingleton` : Core, Repositories, Datasources
- `registerFactory` : BLoCs (nouvelle instance à chaque fois)
- Enregistrement dans `lib/core/di/injection.dart`

### 6. Hive — Stockage local

**Uniquement pour :** PIN (chiffré via `flutter_secure_storage`), queue QR offline (`OfflineScanEntry`).  
**Jamais :** tokens Firebase (`FirebaseAuth.instance.currentUser`), données KYC, données sensibles en clair.

`OfflineScanEntry` : `bidId`, `qrCode`, `gpsLat?`, `gpsLon?`, `photoPath?`, `timestamp`, `synced`.

### 7. Offline QR Scanning (CRITIQUE métier)

Les scans QR fonctionnent sans connexion :
- En ligne → `TrackingRepository.submitQrScan()` immédiatement
- Hors ligne → sauvegarde dans `OfflineQueue` (Hive), afficher "En attente de synchronisation…"
- `connectivity_plus` → dès reconnexion, `TrackingSyncRequested` déclenche la synchro (< 30 s, NFR1)
- Le backend valide que `offlineTimestamp` n'est pas dans le futur (anti-fraude)

### 8. QR Photo + GPS

- Capturer `Geolocator.getCurrentPosition()` **avant** `ImagePicker.pickImage()`
- Écrire lat/lon dans les métadonnées EXIF (package `exif`)
- Photo : qualité 85 %, max 1920×1080, taille max 10 MB (valider avant upload)

### 9. Biométrie — Paiements (NFR14)

Avant tout paiement : `LocalAuthentication.authenticate()` avec `biometricOnly: false` (fallback PIN).  
Si l'appareil ne supporte pas la biométrie → afficher `DonyKeypad` pour le PIN.

### 10. FCM — Notifications

- Au démarrage : `PUT /users/me/fcm-token`. Réémettre sur `onTokenRefresh`.
- `POST /notifications/{id}/ack` pour toutes les notifications critiques (paiement, livraison, litige).
- Handler background = fonction top-level annotée `@pragma('vm:entry-point')`.

---

## Git Workflow — OBLIGATOIRE

- Ne jamais commit directement sur `main` — toujours créer une branche dédiée
- Nommage : `feature/<nom>`, `fix/<nom>`, `chore/<nom>`
- Ne jamais inclure `Co-Authored-By: Claude` dans les messages de commit — les commits sont au nom du développeur uniquement

---

## Critical Rules

### NEVER
1. Commit directly on `main` — always use a feature branch
2. Add `Co-Authored-By: Claude` in commit messages
3. `setState` → BLoC
4. `Navigator.push()` → GoRouter
5. Package `http` → Dio
6. Instancier services dans widgets/BLoCs → GetIt
7. Données sensibles dans Hive en clair
8. Tokens Firebase dans Hive → `FirebaseAuth.instance.currentUser`
9. Photos > 10 MB
10. Paiement sans biométrie/PIN
11. GPS oublié dans les métadonnées EXIF
12. URLs/clés hardcodées → `--dart-define-from-file`

### ALWAYS
1. BLoC pour tout état de feature
2. GoRouter avec auth guard
3. Dio + `AuthInterceptor`
4. Hive pour queue QR offline
5. Synchro automatique à la reconnexion
6. GPS capturé avant la photo
7. Biométrie/PIN avant paiement
8. ACK FCM pour notifications critiques
9. FCM token mis à jour sur `onTokenRefresh`
10. Validation côté client (backend = source de vérité)

---

## Règle — Rafraîchissement des données après navigation (OBLIGATOIRE)

> **Contexte :** Chaque route crée une nouvelle instance BLoC (`registerFactory`). L'écran parent et l'écran fils ont donc des BLoCs distincts. Sans signal explicite, le parent ne sait jamais qu'une donnée a changé.

### Pattern selon le type de navigation

**A — `context.push()` vers un écran d'édition/création :**

```dart
// ✅ CORRECT — écran liste
onTap: () async {
  final changed = await context.push<bool>('/profile/addresses/${address.id}');
  if ((changed ?? false) && context.mounted) {
    context.read<XxxBloc>().add(const XxxListRequested());
  }
},

// ✅ CORRECT — écran d'édition (dans le BlocListener après succès)
if (state.status == XxxStatus.success) {
  context.pop(true);  // true = signale un changement réel
}

// ❌ INTERDIT
onTap: () => context.push('/profile/addresses/${address.id}'),  // non awaité
context.pop();  // sans valeur après une sauvegarde
```

**B — BottomSheet de création/édition :**

```dart
// ✅ CORRECT — toujours awaiter les bottom sheets qui modifient des données
onPressed: () async {
  await CreateXxxBottomSheet.show(context);
  if (context.mounted) {
    context.read<XxxBloc>().add(const XxxListRequested());
  }
},

// ❌ INTERDIT
onPressed: () => CreateXxxBottomSheet.show(context),  // non awaité
```

**C — Exception : BLoC partagé (pas de refresh nécessaire)**

Si le bottom sheet utilise `context.read<XxxBloc>()` depuis le provider du parent (même instance), le parent se reconstruit automatiquement. Pas besoin du pattern await/refresh.

Cas typiques en shared BLoC : `HandoverBottomSheet` (BidBloc), bottom sheets de négociation (NegotiationBloc), `EditProfileBottomSheet` (AuthBloc).

### Règles de diagnostic

Avant de naviguer vers un écran fils, se poser ces questions :
1. **Est-ce que cet écran peut modifier des données ?** Si non → pas de refresh nécessaire.
2. **Le BLoC parent et le BLoC fils sont-ils la même instance ?** Si oui → pas de refresh (shared BLoC).
3. **C'est `context.push()` ?** → `await context.push<bool>()` + `if (result == true) reload`.
4. **C'est un bottom sheet qui modifie des données ?** → `await Sheet.show()` + reload.
5. **L'écran fils appelle `context.pop()` après save ?** → `context.pop(true)` si le caller conditionne le reload sur le résultat.

### Checklist à appliquer à chaque nouvel écran/bottom sheet

- [ ] Tout `context.push()` vers écran qui crée/modifie → `await context.push<bool>()` + reload conditionnel
- [ ] Tout `BottomSheet.show()` qui modifie des données → `await Sheet.show()` + reload
- [ ] Tout `context.pop()` dans un BlocListener après succès → `context.pop(true)`
- [ ] Pas de `unawaited(context.push(...))` vers un écran d'édition

---

## Feature Implementation Checklist

**Avant de commencer :**
- [ ] Lire la story dans `/docs-claude/docs/stories/epic-XX-*.md`
- [ ] BLoC (events + states + bloc)
- [ ] Data models (`fromJson`/`toJson`) + repository + datasource
- [ ] Routes dans `lib/app/router.dart`
- [ ] DI dans `lib/core/di/injection.dart`

**Avant de marquer complète :**
- [ ] Tous les critères Given/When/Then couverts
- [ ] BLoC (no `setState`), GoRouter (no `Navigator`)
- [ ] Loading + Error states gérés avec messages utilisateur
- [ ] Support offline si requis · Biométrie/PIN si paiement · ACK FCM si notifications
- [ ] Tests unitaires BLoC + widget tests écrans critiques
- [ ] Couverture ≥ 90 % (`flutter test --coverage`)

---

## Testing

- BLoC : `blocTest<XBloc, XState>` → `build` / `act` / `expect`
- Widgets : `tester.pumpWidget(BlocProvider(...))` + `find.byType()` / `find.text()`
- Couverture ≥ 90 % — tous les tests passent avant tout commit

---

## Design et UI — HIG + Material 3

> **RÈGLE ABSOLUE :** Tout écran doit être conforme aux Apple HIG et Material Design 3. Un refus App Store / Play Store pour non-conformité est inacceptable.

### Bibliothèques obligatoires

| Package | Usage |
|---------|-------|
| `flutter_animate` | Micro-animations et transitions |
| `google_fonts` | **Plus Jakarta Sans** — tous les textes |
| `pinput` | Champ PIN/OTP |
| `flutter_secure_storage` | Stockage PIN (Keystore/Keychain) |

### Palette (source de vérité : `lib/app/theme.dart`)

```dart
const kGreenPrimary  = Color(0xFF1A6B3C);  // CTA, actifs
const kGreenDark     = Color(0xFF134F2D);  // gradients, headers
const kGreenAccent   = Color(0xFF4CAF7D);  // accents secondaires
const kGreenLight    = Color(0xFFE8F5EE);  // bg chips actifs
const kBackground    = Color(0xFFF4F6F8);  // fond (jamais blanc pur)
const kSurface       = Color(0xFFFFFFFF);  // cards, inputs, appbar
const kTextPrimary   = Color(0xFF0D1B2A);
const kTextSecondary = Color(0xFF6B7A8D);
const kTextHint      = Color(0xFFADB5BD);
const kBorder        = Color(0xFFE9ECEF);
const kError         = Color(0xFFE53935);
const kWarning       = Color(0xFFF59E0B);
const kSuccess       = Color(0xFF16A34A);
```

### Règles HIG obligatoires

**Typographie :** `GoogleFonts.plusJakartaSans` partout. `fontSize < 12` interdit. Contraste ≥ 4.5:1.
- Grand titre : `28–32 / w800 / letterSpacing -0.5`
- Titre nav : `17–18 / w700` · Section : `15–16 / w600` · Corps : `14–15 / w400` · Caption : `12–13 / w500`

**Touch targets :** min 44×44 pt pour tout élément interactif. `InkWell`/`GestureDetector` avec padding suffisant.

**Navigation :**
- Back iOS → `Icons.arrow_back_ios_rounded` (taille 20, `kGreenPrimary`), Android → `Icons.arrow_back_rounded`
- `centerTitle: false`. Écrans principaux : `SliverAppBar(expandedHeight: 100–120)`.

**Bottom sheets :**
- Handle : `Container(width: 40, height: 4, color: kBorder)`
- `isScrollControlled: true` · `borderRadius: BorderRadius.vertical(top: Radius.circular(20))`
- Respecter `MediaQuery.of(context).viewInsets.bottom`
- Dialogs uniquement pour actions destructives irréversibles.

**Couleurs :** jamais `0xFFFFFFFF` en fond → `kBackground`. Gradients uniquement sur hero cards/headers.

**Espacement :** padding horizontal 20 pt. Entre sections 24–28 pt. Interne cards 16 pt.  
Border radius : cards 16 · boutons 14 · chips 20 · inputs 12 · badges 8.

**Animations (`flutter_animate`) :** entrée 250–300 ms `easeOutCubic`, sortie 150–200 ms `easeInCubic`. Stagger : 60 ms × index. Max 500 ms.

**États :**
- Loading → `CircularProgressIndicator(color: kGreenPrimary)` centré
- Erreur → icône + titre + description + "Réessayer"
- Vide → illustration + titre + CTA
- Désactivé → `opacity: 0.4`

**Formulaires :** labels flottants (`labelText`). Validation à la perte de focus. Submit désactivé (`onPressed: null`) pendant loading. `suffixText` pour les unités (€, kg).

**Accessibilité :** `Semantics` sur icônes sans label. `tooltip` sur `IconButton`. Info jamais transmise par couleur seule.

### Material 3

`useMaterial3: true`. `ElevatedButton` elevation 0. Cards elevation 0 + border `kBorder`. `SnackBarBehavior.floating` radius 12. `AppBar scrolledUnderElevation: 0`.

### PIN — standard dony

Utiliser `DonyKeypad` (`lib/core/widgets/dony_keypad.dart`) — ne jamais recréer le clavier.
```dart
PinTheme(width: 56, height: 64,
  decoration: BoxDecoration(color: kGreenLight,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: kGreenPrimary, width: 2)))
```

### Templates d'écrans

**Écran secondaire :**
```dart
Scaffold(
  backgroundColor: kBackground,
  appBar: AppBar(
    title: Text('Titre', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
    backgroundColor: kSurface, elevation: 0,
    bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
  ),
  body: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
    child: Column(children: [/* contenu */])
        .animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  ),
)
```

**Écran principal (Large Title) :**
```dart
Scaffold(
  backgroundColor: kBackground,
  body: CustomScrollView(slivers: [
    SliverAppBar(
      pinned: true, expandedHeight: 110,
      backgroundColor: kSurface, elevation: 0, surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text('Grand titre', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700)),
        expandedTitleScale: 1.5,
      ),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: kBorder, height: 1)),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      sliver: SliverList(delegate: SliverChildListDelegate([/* contenu */])),
    ),
  ]),
)
```

---

## Performance

- Images : max 10 MB, qualité 85 %, 1920×1080. `CachedNetworkImage` dans les listes.
- Listes longues : `ListView.builder` + pagination 20 items.
- `dispose()` : fermer BLoCs, désabonner streams, annuler timers.
- Réseau : retry exponential backoff. Cache si possible.

---

## Security Checklist

- [ ] Aucun secret dans le code → `--dart-define-from-file`
- [ ] Biométrie/PIN pour paiements
- [ ] Firebase token auto-refreshed (jamais stocké dans Hive)
- [ ] HTTPS uniquement + SSL pinning en production
- [ ] ProGuard/R8 + obfuscation activés (release)
- [ ] Aucune donnée sensible dans les logs en production
- [ ] Sentry configuré

---

## Documentation story complète

Créer `docs/stories-done/story-<epic>.<num>-<slug>.md` quand la story est **100% terminée**.

```markdown
# Story X.Y — Titre (Flutter)
**Date:** YYYY-MM-DD | **Status:** ✅ Complète

## Résumé
## Fichiers créés / modifiés
## Comment ça fonctionne
### Flux utilisateur (étape par étape)
### BLoC : events, states, transitions importantes
### Écrans et widgets clés (ce qu'ils affichent, quel BLoC, quelle navigation)
### Appels API (endpoint, body, gestion erreurs)
### Pièges et points d'attention
## Critères d'acceptation couverts
## Décisions techniques
```

**Règles :** ne pas créer avant 100% terminé · inclure les critères d'acceptation · "Comment ça fonctionne" doit permettre la maintenance sans relire tout le code.

---

## Documentation

- Architecture : `/docs-claude/docs/planning-artifacts/architecture.md`
- Stories : `/docs-claude/docs/stories/epic-*.md`
- PRD : `/docs-claude/docs/planning-artifacts/prd.md`
