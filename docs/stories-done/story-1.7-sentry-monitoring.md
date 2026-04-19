# Story 1.7 — Configuration Sentry (Flutter)

**Date:** 2026-04-19
**Status:** ✅ Complète

## Résumé
Sentry Flutter est initialisé dans `main.dart` avec `SentryFlutter.init()` et un `SentryNavigatorObserver` est ajouté au GoRouter pour capturer le contexte de navigation dans chaque rapport d'erreur.

## Fichiers modifiés
- `lib/main.dart` — wrapping de l'initialisation dans `SentryFlutter.init()` avec DSN depuis `--dart-define`, `tracesSampleRate=0.1`, `sendDefaultPii=false`
- `lib/app/router.dart` — ajout de `observers: [SentryNavigatorObserver()]` sur `GoRouter`

## Critères d'acceptation couverts
- [x] Exception Flutter non catchée capturée et envoyée à Sentry (via `SentryFlutter.init` qui configure les handlers Flutter)
- [x] Stack trace Dart incluse dans le rapport (automatique via Sentry SDK)
- [x] Contexte de navigation GoRouter : `SentryNavigatorObserver` ajoute les breadcrumbs de navigation à chaque rapport
- [x] DSN lu depuis `--dart-define-from-file` (variable `SENTRY_DSN`)
- [x] PII non envoyé : `sendDefaultPii=false`

## Décisions techniques
- `SentryFlutter.init()` avec `appRunner` est le pattern recommandé pour capturer les erreurs Flutter dès le démarrage, y compris pendant l'initialisation.
- Sentry est désactivé en dev si `SENTRY_DSN` est vide (pas de DSN dans `env.dev.json`) — l'app démarre directement sans Sentry.
- Le contexte utilisateur Firebase (UID) sera ajouté via `Sentry.configureScope` dans la story 2.x (Auth), une fois l'authentification implémentée.

## ⚠️ À FAIRE EN PRODUCTION

Avant le passage en production, configurer Sentry :

### 1. Créer les projets sur sentry.io
- Un projet **Flutter** → récupérer le DSN Flutter
- Un projet **Java/Spring Boot** → récupérer le DSN backend

### 2. Flutter — `env.prod.json`
```json
"SENTRY_DSN": "https://TON_DSN@o123456.ingest.sentry.io/789456",
"ENVIRONMENT": "production"
```

### 3. Backend — variable d'environnement sur le serveur Hetzner
```bash
SENTRY_DSN=https://TON_DSN_JAVA@o123456.ingest.sentry.io/789456
```
La config `application-prod.yml` lit déjà `${SENTRY_DSN}` — rien d'autre à modifier.

### 4. Vérifier que le contexte utilisateur Firebase est attaché
Dans `AuthBloc` (story 2.x), ajouter après connexion :
```dart
await Sentry.configureScope((scope) {
  scope.setUser(SentryUser(id: firebaseUid));
});
```
