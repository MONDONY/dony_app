# Notification Settings Screen — Redesign Spec

**Date:** 2026-05-22  
**Status:** Approuvé

## Contexte

L'écran `/settings/notifications` actuel présente 5 sections et 11 toggles. Après analyse des 20 types de notifications push du système, 3 problèmes majeurs ont été identifiés :

1. **Toggles SMS trompeurs** — affichés dans l'UI mais ne contrôlent rien : les SMS sont un fallback automatique du backend (`SmsFallbackScheduler`) déclenché 60s après un push non acquitté. Aucun endpoint backend ne lit ces préférences.
2. **Notifications critiques désactivables** — paiement, livraison et litige peuvent être coupées par l'utilisateur, ce qui le prive de protections essentielles.
3. **7 types manquants** — les 7 types de négociation Package Request (`negotiation_*`, `request_*`) et `NEW_MESSAGE` ne sont pas représentés.

## Objectif

Réorganiser l'écran en 3 niveaux d'importance clairs, couvrir les 20 types de notifications existants, et supprimer les faux contrôles SMS.

---

## Structure des données — NotificationPrefsBloc

### Clés Hive supprimées

| Clé | Raison |
|-----|--------|
| `push_payment` | Notification critique — non-désactivable |
| `sms_payment` | SMS est un mécanisme backend automatique, pas une préférence utilisateur |
| `push_delivery` | Notification critique — non-désactivable |
| `sms_delivery` | SMS est un mécanisme backend automatique |
| `push_match` | Remplacé par `push_activity_bids` au périmètre élargi |
| `push_dispute` | Notification critique — non-désactivable |
| `sms_dispute` | SMS est un mécanisme backend automatique |
| `email_dispute` | Hors scope MVP |

### Clés Hive conservées

| Clé | Défaut | Usage |
|-----|--------|-------|
| `push_trip_reminder` | `true` | Rappel trajet J-1 (`TRIP_IN_PROGRESS`) |
| `push_promo` | `false` | Actus dony Push |
| `email_promo` | `false` | Actus dony E-mail |

### Clés Hive ajoutées

| Clé | Défaut | Types couverts |
|-----|--------|---------------|
| `push_activity_bids` | `true` | `BID_CREATED`, `BID_ACCEPTED`, `BID_REJECTED`, `HANDOVER_DEFINED`, `PARCEL_REFUSED`, `BID_EXPIRED`, `TRIP_CANCELLED` |
| `push_activity_negotiations` | `true` | `negotiation_started`, `negotiation_counter`, `negotiation_awaiting_trip`, `negotiation_awaiting_payment`, `request_accepted`, `request_expired`, `negotiation_expired` |
| `push_messages` | `true` | `NEW_MESSAGE` |

**Total : 6 clés** (vs 11 actuelles dont 5 sans effet réel).

---

## Structure de l'écran

### Section 1 — PROTECTIONS CRITIQUES

Header de section avec couleur `error` (rouge).

3 tiles verrouillées, non-interactives :

| Tile | Icône | Sous-titre |
|------|-------|-----------|
| Livraison confirmée | `verified_rounded` | "SMS automatique si push non reçu" |
| Paiement reçu | `payments_rounded` | "SMS automatique si push non reçu" |
| Litige ouvert | `gavel_rounded` | "SMS automatique si push non reçu" |

Comportement des tiles verrouillées :
- `Switch(value: true, onChanged: null)` → Switch grisé nativement par Flutter
- `onTap: null` — aucun feedback au tap
- Fond de tuile : `colorScheme.errorContainer.withOpacity(0.08)`
- Trailing : label "Toujours actif" (texte `labelSmall`, couleur `error`) à la place du Switch

Bandeau informatif sous les 3 tiles :
- Icône `Icons.info_outline_rounded` + texte : *"Ces notifications protègent vos transactions. Elles ne peuvent pas être désactivées."*
- Fond `errorContainer.withOpacity(0.08)`, border-radius 12, padding 12

### Section 2 — ACTIVITÉ

Header de section avec couleur `tertiary` (orange/ambre).

4 tiles avec Switch actif :

| Clé Hive | Label | Sous-titre | Icône |
|----------|-------|-----------|-------|
| `push_activity_bids` | Matchs & enchères | "Demandes, acceptations, remise, annulation…" | `handshake_rounded` |
| `push_activity_negotiations` | Négociations | "Propositions, contre-offres, paiements…" | `forum_rounded` |
| `push_messages` | Messages | "Nouveaux messages reçus" | `chat_bubble_rounded` |
| `push_trip_reminder` | Rappel trajet J-1 | "La veille de chaque trajet" | `calendar_today_rounded` |

Comportement : `Switch` avec `onChanged` actif, `onTap` dispatche `NotifPrefToggled(key)`. Icône active = `notifications_active_rounded` (couleur `primary`), inactive = `notifications_off_outlined` (couleur `onSurfaceVariant`).

### Section 3 — ACTUS & PROMOTIONS

Header de section avec couleur `onSurfaceVariant` (gris).

2 tiles, désactivées par défaut :

| Clé Hive | Label | Icône |
|----------|-------|-------|
| `push_promo` | Actus dony (Push) | `campaign_rounded` |
| `email_promo` | Actus dony (E-mail) | `email_rounded` |

Comportement identique aux tiles d'activité.

---

## Composants Flutter

### `_LockedTile` (widget privé)

```dart
Widget _buildLockedTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String subtitle,
})
```

- Fond `colorScheme.errorContainer.withOpacity(0.08)` sur le `Container` wrappant la `DonyListTile`
- `DonyListTile` avec `subtitle: subtitle`, `trailing: _LockedBadge()`
- `_LockedBadge` : `Container` avec texte "Toujours actif", fond `errorContainer`, couleur `onErrorContainer`

### `_buildTile()` (existant, inchangé)

Signature conservée :
```dart
DonyListTile _buildTile(BuildContext context, {
  required String label,
  required String key,
  required Map<String, bool> prefs,
  required void Function(String) onToggle,
  String? subtitle,
})
```

Le paramètre `subtitle` (optionnel) est ajouté pour afficher le sous-titre descriptif sur les tiles d'activité.

### `_buildSection()` (existant, signature étendue)

```dart
Widget _buildSection(BuildContext context, {
  required String title,
  required List<Widget> tiles,
  Color? titleColor,
  Widget? footer,
})
```

- `titleColor` : permet de colorer le header par section (error / tertiary / onSurfaceVariant)
- `footer` : widget optionnel affiché après les tiles (bandeau informatif pour les critiques)

---

## Animation

Entrée de l'écran conservée :
```dart
.animate()
.fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
.slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic)
```

---

## Tests

### `notification_prefs_bloc_test.dart` (mis à jour)

- Toggle `push_activity_bids` false → true
- Toggle `push_activity_negotiations` true → false
- Toggle `push_messages` false → true
- Suppression des tests des clés obsolètes (`push_payment`, `sms_payment`, etc.)
- État initial : `push_activity_bids = true`, `push_activity_negotiations = true`, `push_messages = true`

### `notification_settings_screen_test.dart` (créé)

- Render : section "PROTECTIONS CRITIQUES" affichée
- Render : tiles "Livraison confirmée", "Paiement reçu", "Litige ouvert" présentes
- Render : bandeau "Ces notifications protègent vos transactions" affiché
- Comportement : tap sur "Livraison confirmée" ne dispatche aucun event
- Render : section "ACTIVITÉ" avec 4 tiles
- Comportement : tap "Matchs & enchères" dispatche `NotifPrefToggled('push_activity_bids')`
- Comportement : tap "Négociations" dispatche `NotifPrefToggled('push_activity_negotiations')`
- Comportement : tap "Messages" dispatche `NotifPrefToggled('push_messages')`
- Render : section "ACTUS & PROMOTIONS" avec 2 tiles

---

## Périmètre exclu

**Filtrage effectif des notifications** : faire que `notification_service.dart` lise les prefs Hive et supprime les notifications push locales selon les préférences utilisateur. Cette fonctionnalité est une amélioration séparée — les prefs restent purement UI dans ce spec.

**Synchronisation backend** : aucun endpoint `/users/me/notification-prefs` n'existe. Les prefs restent locales (Hive uniquement).

---

## Fichiers modifiés

| Fichier | Action |
|---------|--------|
| `lib/features/settings/bloc/notification_prefs_bloc.dart` | Mettre à jour `_defaults` (6 clés) |
| `lib/features/settings/presentation/screens/notification_settings_screen.dart` | Réécriture complète `build()` + nouveaux widgets privés |
| `test/features/settings/bloc/notification_prefs_bloc_test.dart` | Mettre à jour les tests |
| `test/features/settings/presentation/notification_settings_screen_test.dart` | Créer (9 tests) |
