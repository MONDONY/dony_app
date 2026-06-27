# DonySnackbar v2 — Redesign & Migration

**Date:** 2026-06-25  
**Branch:** feature/chat-redesign  
**Scope:** `lib/core/design/widgets/dony_snackbar.dart` + migration de 40+ fichiers

---

## Problèmes résolus

1. **Toasts multiples pour une même action** — 40+ fichiers utilisent `ScaffoldMessenger.of(ctx).showSnackBar()` brut sans `hideCurrentSnackBar()`, causant une file de toasts.
2. **Double-émission BLoC** — certains listeners déclenchent plusieurs états → plusieurs toasts identiques.
3. **Incohérence visuelle** — mélange de `SnackBar` brut avec `backgroundColor: kError` hardcodé et `DonySnackbar` stylé.

---

## Architecture

### `DonySnackbar` (modifié)

**Fichier :** `lib/core/design/widgets/dony_snackbar.dart`

**Dedup :**
```dart
static final Map<String, DateTime> _lastShown = {};

static bool _isDuplicate(String key) {
  final last = _lastShown[key];
  if (last == null) return false;
  return DateTime.now().difference(last) < const Duration(milliseconds: 400);
}
```
- Clé = `"$type:$message"`
- Skip si même clé affichée depuis < 400ms
- Nettoie les entrées > 5s à chaque appel (évite la fuite mémoire)

**Visuel (style B — fond coloré + cercle icône) :**
- Fond coloré plein par type
- Dégradé overlay : `linear-gradient(135deg, rgba(255,255,255,0.12), transparent)`
- Icône dans `CircleAvatar` blanc semi-transparent : `rgba(255,255,255,0.22)` + bordure `rgba(255,255,255,0.35)`
- Icône auto si non fournie : `Icons.check_circle_outline` / `Icons.error_outline` / `Icons.warning_amber_rounded` / `Icons.info_outline`
- Ombre colorée : `BoxShadow(color: typeColor.withValues(alpha: 0.40), blurRadius: 20, offset: Offset(0, 8))`
- `borderRadius: 16`, padding `EdgeInsets.symmetric(horizontal: 14, vertical: 12)`
- Bouton dismiss `×` toujours présent (tap = `hideCurrentSnackBar`)
- Bouton action optionnel : texte blanc, `fontWeight: w700`, underline

**Couleurs par type :**

| Type    | Background  | Shadow               |
|---------|-------------|----------------------|
| success | `cs.success` | `success @ 0.40`    |
| error   | `cs.error`   | `error @ 0.40`      |
| warning | `cs.warning` | `warning @ 0.40`    |
| info    | `cs.inverseSurface` | `inverseSurface @ 0.40` |

### `ErrorPresenter` (inchangé)
Déjà propre — route vers `DonySnackbar.show()`. Aucune modification.

---

## Migration — 40+ fichiers

Tous les appels bruts remplacés par `DonySnackbar.show()` :

```dart
// AVANT
ScaffoldMessenger.of(ctx).showSnackBar(
  SnackBar(content: Text('Erreur'), backgroundColor: kError),
);

// APRÈS
DonySnackbar.show(ctx, message: 'Erreur', type: DonySnackbarType.error);
```

**Règles de mapping :**
- `backgroundColor: kError` → `type: DonySnackbarType.error`
- `backgroundColor: kSuccess` (si présent) → `type: DonySnackbarType.success`
- Erreurs Stripe `FailureCode.Canceled` → message `'Paiement annulé'`, type `warning`
- Erreurs Stripe autres → message traduit, type `error`
- Erreurs auth (`'Authentification requise...'`) → type `warning`
- `catch (_)` génériques → `'Une erreur est survenue. Veuillez réessayer.'`, type `error`

**Fichiers prioritaires (paiement/auth) :**
- `payment_recap_bottom_sheet.dart`
- `accept_offer_bottom_sheet.dart`
- `make_offer_bottom_sheet.dart`
- `complete_details_screen.dart`
- `package_request_detail_screen.dart`

**Autres fichiers :**
- `create_announcement_screen.dart`
- `bid_detail_action_bars.dart`
- `traveler_options_sheet.dart`
- `block_user_action.dart`
- `step_1_trajet_colis.dart`
- `package_request_public_detail_screen.dart`
- `link_trip_screen.dart`
- `change_pin_screen.dart`
- `account_rejected_screen.dart`
- `home_screen.dart`
- `map_traveler_view.dart`
- `commission_method_screen.dart`
- `qr_scanner_screen.dart`
- `chat_screen.dart`
- `archived_conversations_screen.dart`
- `corridor_alert_form_sheet.dart`
- `dony_feedback_button.dart`
- `conversation_list_screen.dart`
- `create_wizard/package_request_create_screen.dart`

---

## Critères d'acceptation

- [ ] Afficher le même toast deux fois de suite en < 400ms → un seul toast visible
- [ ] 4 types visuellement distincts avec fond coloré + ombre colorée + icône cercle
- [ ] Aucun `ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(...))` brut restant dans le codebase
- [ ] `flutter analyze` sans warning nouveau
- [ ] Tests unitaires `DonySnackbar` : dedup, 4 types, action callback
