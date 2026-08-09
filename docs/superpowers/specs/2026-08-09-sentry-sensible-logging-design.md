# Sentry sensible logging

## Objectif

Capturer les incidents réellement utiles au diagnostic sans transformer chaque
erreur métier attendue en issue Sentry ni exposer de données sensibles.

## Design

Un `ErrorReportingService` centralise les captures Sentry. Il reçoit une erreur,
sa stacktrace, une opération et un contexte PII-free. Il filtre les erreurs
attendues (annulation, validation, 401/403/404/409/422) et normalise les chemins
HTTP avant capture.

L’observer BLoC est installé indépendamment de PostHog et utilise ce service
pour les erreurs qui échappent aux handlers. Dio capture uniquement les erreurs
finales critiques (transport et 5xx), tout en conservant les breadcrumbs pour
le reste. Les flux sensibles (paiement, KYC, authentification, offline,
notifications et Firebase) ajoutent seulement des captures aux frontières où
une erreur est avalée ou transformée en état générique.

Toutes les métadonnées excluent les corps HTTP, headers, tokens, téléphone,
email, adresses, KYC et messages backend bruts. Les tests vérifient le filtrage,
la normalisation et le câblage indépendant de PostHog.

## Hors périmètre

- Aucun logging de chaque transition BLoC ou requête réussie.
- Aucun changement de comportement UI ou de stratégie de retry.
- Aucun ajout de PII utilisateur dans Sentry.
