# Sentry sensible logging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter une télémétrie Sentry ciblée sur les erreurs critiques sans PII ni dépendance à PostHog.

**Architecture:** Un service central filtre et capture les erreurs, l’observer BLoC et Dio l’utilisent aux frontières critiques. Les flux sensibles ajoutent uniquement un contexte d’opération lorsque leurs erreurs sont autrement avalées ou généralisées.

**Tech Stack:** Flutter/Dart, flutter_bloc, Dio, sentry_flutter 9.21.0, flutter_test.

## Global Constraints

- Ne jamais envoyer de token, body HTTP, email, téléphone, adresse, KYC ou secret.
- Les erreurs attendues 401/403/404/409/422, validation et annulation restent hors issues Sentry.
- Aucun changement de stratégie retry ou de comportement utilisateur.
- Préserver les changements non liés et ne pas travailler sur `main`.

### Task 1: Reporter central et filtres

**Files:**
- Create: `lib/core/services/error_reporting_service.dart`
- Test: `test/core/services/error_reporting_service_test.dart`

- [ ] Écrire les tests du filtre et de la normalisation.
- [ ] Vérifier l’échec des tests avant implémentation.
- [ ] Implémenter le reporter avec contexte PII-free et capture uniquement critique.
- [ ] Vérifier les tests ciblés.

### Task 2: BLoC et Dio

**Files:**
- Modify: `lib/core/services/analytics_bloc_observer.dart`
- Modify: `lib/main.dart`
- Modify: `lib/core/network/api_client.dart`
- Test: `test/core/network/sentry_error_interceptor_test.dart`

- [ ] Écrire les tests de capture des erreurs Dio critiques et d’exclusion des erreurs attendues.
- [ ] Découpler l’observer BLoC de PostHog.
- [ ] Brancher Dio sur le reporter sans capturer deux fois la même erreur.
- [ ] Vérifier les tests ciblés et l’analyse statique.

### Task 3: Frontières sensibles

**Files:**
- Modify: `lib/features/payments/bloc/payment_sheet_bloc.dart`
- Modify: `lib/features/kyc/bloc/kyc_bloc.dart`
- Modify: `lib/features/tracking/data/offline_sync_service.dart`
- Modify: `lib/features/notifications/data/notification_service.dart`
- Modify: `lib/features/messaging/data/firestore_chat_repository.dart`

- [ ] Ajouter des captures uniquement dans les catches génériques critiques qui perdent actuellement l’erreur.
- [ ] Ajouter les tests de non-régression nécessaires.
- [ ] Vérifier analyse et tests complets.

### Task 4: Vérification finale

- [ ] Contrôler le diff et l’absence de secrets/PII.
- [ ] Exécuter `flutter analyze`.
- [ ] Exécuter `flutter test --coverage`.
- [ ] Committer sur `fix/sentry-sensible-logging`.
