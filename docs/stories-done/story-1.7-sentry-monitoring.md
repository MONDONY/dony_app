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
- Le contexte utilisateur Firebase (UID) sera ajouté via `Sentry.configureScope` dans la story 2.x (Auth), une fois l'authentification implémentée.
