# Stories 2.4 & 2.5 — KYC Stripe Identity (Flutter)

**Date:** 2026-04-19
**Status:** ✅ Complètes

## Résumé
Implémentation du flow KYC côté Flutter : écran d'onboarding expliquant le processus, WebView Stripe Identity pour la vérification, écran de statut avec polling automatique toutes les 30s.

## Fichiers créés
- `lib/features/kyc/bloc/kyc_event.dart` — KycSessionRequested, KycStatusRefreshed
- `lib/features/kyc/bloc/kyc_state.dart` — Initial, Loading, SessionCreated, StatusLoaded, Error
- `lib/features/kyc/bloc/kyc_bloc.dart` — orchestration session + polling statut
- `lib/features/kyc/data/repositories/kyc_repository.dart` — createSession(), getStatus()
- `lib/features/kyc/presentation/screens/kyc_onboarding_screen.dart` — explication + bouton "Commencer"
- `lib/features/kyc/presentation/screens/kyc_webview_screen.dart` — WebView Stripe Identity
- `lib/features/kyc/presentation/screens/kyc_status_screen.dart` — affichage statut + polling

## Fichiers modifiés
- `pubspec.yaml` — ajout `webview_flutter: ^4.10.0`
- `lib/app/router.dart` — remplacement placeholder `/kyc` par KycOnboardingScreen, ajout `/kyc/verify` et `/kyc/status`
- `lib/core/di/injection.dart` — enregistrement KycRepository (singleton) et KycBloc (factory)
- `lib/app/app.dart` — ajout `BlocProvider<KycBloc>`

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur
1. Après setup PIN → `context.go('/kyc')` → `KycOnboardingScreen`
2. Clic "Commencer la vérification" → `KycSessionRequested` dispatché
3. `KycBloc` appelle `POST /kyc/session` → reçoit `stripeUrl`
4. Emit `KycSessionCreated(stripeUrl)` → listener navigue vers `/kyc/verify` avec `stripeUrl` en `extra`
5. `KycWebViewScreen` charge la WebView avec l'URL Stripe
6. L'utilisateur fait la vérification dans la WebView
7. Stripe redirige vers `dony://kyc/complete` → `NavigationDelegate` intercepte → `context.go('/kyc/status')`
8. `KycStatusScreen.initState` dispatch `KycStatusRefreshed`
9. Si statut PENDING → `Timer.periodic(30s)` démarre → re-dispatche `KycStatusRefreshed` toutes les 30s
10. Si statut VERIFIED → affiche badge vert + bouton "Accéder à l'app" → `context.go('/home')`
11. Si statut REJECTED → affiche message + bouton "Réessayer" → `context.go('/kyc')`

### BLoC : events et states
- **`KycSessionRequested`** : déclenché par le bouton "Commencer". Appelle `POST /kyc/session`.
- **`KycStatusRefreshed`** : déclenché dans `initState` de KycStatusScreen et par le Timer polling.
- **`KycSessionCreated(stripeUrl, sessionId)`** : navigue vers `/kyc/verify`.
- **`KycStatusLoaded(kycStatus, verificationStatus)`** : affiche l'état correct selon `kycStatus` (PENDING/VERIFIED/REJECTED).

### Écrans et widgets clés

**`KycOnboardingScreen`** :
- Pas de `StatefulWidget` — tout le state est dans le BLoC
- Le `BlocConsumer` écoute `KycSessionCreated` pour naviguer vers la WebView
- Le bouton est désactivé pendant `KycLoading` (montre CircularProgressIndicator)

**`KycWebViewScreen`** :
- `WebViewController` avec `JavaScriptMode.unrestricted` (requis par Stripe Identity)
- `NavigationDelegate.onNavigationRequest` intercepte `dony://kyc/complete`
- Bouton "X" ferme la WebView et retourne à `/kyc` (l'utilisateur peut abandonner)
- Indicateur de chargement pendant `onPageStarted` / `onPageFinished`

**`KycStatusScreen`** :
- `Timer.periodic(30s)` géré dans le widget (comme LocalAuthScreen pour le countdown)
- `_stopPolling()` appelé dès que le statut n'est plus PENDING
- `dispose()` annule le Timer pour éviter les memory leaks
- Les 3 états visuels : amber (PENDING), vert (VERIFIED), rouge (REJECTED)

### Polling statut
Le Timer est dans le widget et non dans le BLoC pour la même raison que le countdown de LocalAuthScreen : l'`Emitter` BLoC n'est valide que pendant le handler d'un event. Le widget dispatche `KycStatusRefreshed` régulièrement et le BLoC exécute l'appel API à chaque dispatch.

### Pièges et points d'attention
- **`webview_flutter` nécessite un full rebuild** après ajout dans pubspec.yaml (comme `flutter_secure_storage`). Hot restart ne suffit pas.
- **JavaScript obligatoire** : `JavaScriptMode.unrestricted` est requis, sinon la WebView Stripe affiche une page vide.
- **`state.extra as String`** dans le router pour `/kyc/verify` : si on navigue vers cette route sans `extra`, l'app crashe. Toujours passer via `context.go('/kyc/verify', extra: stripeUrl)`.
- **`_pollingTimer?.cancel()` dans `dispose()`** : si l'utilisateur quitte KycStatusScreen pendant le polling, le Timer doit être annulé. Sans ça, `context.read<KycBloc>()` dans le callback Timer levera une exception sur un widget démonté.
- **deep link `dony://kyc/complete`** : Stripe redirige vers cette URL custom après vérification. Sans `NavigationDelegate.onNavigationRequest`, le WebView essaierait de charger cette URL et échouerait (scheme non supporté → erreur réseau).

## Critères d'acceptation couverts
- [x] kycStatus = PENDING → bouton "Commencer" → WebView Stripe s'ouvre
- [x] Verification complète → retour automatique → écran statut PENDING
- [x] Webhook reçu par backend → polling Flutter détecte VERIFIED → badge vert affiché
- [x] Statut REJECTED → bouton "Réessayer" → retour à l'onboarding

## Décisions techniques
- **`webview_flutter` plutôt qu'un browser externe** : `url_launcher` ouvrirait le browser système, rendant le retour dans l'app incertain. La WebView in-app permet d'intercepter la navigation et d'assurer le retour fluide.
- **Polling toutes les 30s plutôt que FCM push** : Les notifications push (Epic 8) ne sont pas encore implémentées. Le polling est le fallback MVP. Quand Epic 8 sera implémenté, le polling pourra être remplacé/complété par un push FCM → `KycStatusRefreshed`.
- **Pas de `persistConnectionDuration` dans le polling** : le Timer s'arrête dès que l'écran est démonté (dispose) ou que le statut change. Pas de polling en arrière-plan.
