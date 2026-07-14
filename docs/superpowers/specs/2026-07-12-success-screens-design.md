# Écrans de succès unifiés — Design

## Contexte

L'app a 9+ moments "action terminée" (paiement, publication de trajet, création
d'offre/demande, livraison QR...) sans pattern commun. Audit du code existant
(voir historique de conversation) a trouvé 5 traitements différents pour des
moments conceptuellement identiques : vue inline dans une bottom sheet,
écran plein avec mascotte, SnackBar, retour silencieux sans aucun feedback,
et AlertDialog avec mascotte + enchaînement automatique.

Le paiement seul a 3 fins différentes selon le point d'entrée, alors que les
3 partagent le même composant `DonyPaymentSheet`. La publication de trajet a
deux implémentations vivantes avec des philosophies opposées (SnackBar vs
silence total).

## Objectif

Deux niveaux de feedback cohérents pour toute l'app :
- **Majeur** — écran plein `DonySuccessScreen` (mascotte + titre + sous-titre +
  1 CTA) pour les moments à forte charge émotionnelle/transactionnelle :
  paiement confirmé, trajet publié, livraison confirmée.
- **Mineur** — `DonySnackbar` (déjà existant, à généraliser) pour le reste :
  offre envoyée, demande d'envoi publiée, recharge wallet, acceptation
  d'offre en espèces.

Mockup visuel validé par l'utilisateur :
https://claude.ai/code/artifact/b0453823-3319-4490-8864-0d2629664f63

## Hors scope

- Les scans QR intermédiaires (DEPART/TRANSIT, dialog "Scan enregistré !")
  restent inchangés — pas assez de charge émotionnelle pour justifier l'écran
  plein, et changer leur UX n'a pas été demandé. Reste un `AlertDialog`
  existant.
- `CreateAnnouncementBottomSheet` (code mort, aucun call site restant) est
  supprimé dans le cadre de ce chantier car il duplique la logique de
  succès qu'on remplace de toute façon — pas un ajout de scope, un nettoyage
  nécessaire pour ne pas laisser une 3e implémentation obsolète du même
  pattern.

## Composant 1 — `DonySuccessScreen`

**Fichier :** `lib/core/design/widgets/dony_success_screen.dart` (nouveau)

Widget sans état, poussé comme route plein écran (`context.push` via
GoRouter, ou construit directement comme `Scaffold` selon le point d'appel —
voir "Intégration" ci-dessous).

**Props :**
```dart
class DonySuccessScreen extends StatelessWidget {
  const DonySuccessScreen({
    required this.mascotteType,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
    this.ctaGradientColors,  // défaut: gradient bleu primaire (DonyButton standard)
    super.key,
  });

  final DonyMascotteType mascotteType;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;
  final List<Color>? ctaGradientColors;
}
```

**Comportement :**
- Mascotte rendue via `DonyMascotteAnimated(type: mascotteType, withGlow: true, size: DonyMascotteSize.xl)` (widget déjà existant, `lib/core/design/widgets/dony_mascotte.dart`).
- Titre en `headlineSmall` (Hanken Grotesk, w800), sous-titre en `bodyMedium` (Plus Jakarta Sans), couleur `muted`.
- CTA = `DonyButton` existant (pleine largeur, radius 14, gradient), jamais désactivé, jamais de timer/auto-navigation. L'utilisateur déclenche `onCta` lui-même.
- Pas de bouton retour / pas de possibilité de dismiss par swipe — le CTA est l'unique sortie (cohérent avec `_EscrowConfirmedView` actuel et l'`AlertDialog` non-dismissible du scan QR).

**Test widget (`test/core/design/widgets/dony_success_screen_test.dart`) :**
- Rend titre, sous-titre, label du CTA.
- Tap sur le CTA appelle `onCta` exactement une fois.
- Pas de `Navigator.pop` implicite déclenché automatiquement (`tester.pump(Duration(seconds: 5))` puis vérifier que le widget est toujours présent — preuve d'absence d'auto-nav).

## Composant 2 — `DonySnackbar` généralisé

Aucun nouveau widget : `lib/core/design/widgets/dony_snackbar.dart` existe déjà
avec `DonySnackbar.show(context, message:, type:, ...)` et 4 variantes
(`info/success/warning/error`). Le travail ici est d'aligner les 4 sites
mineurs sur cet appel unique, avec `type: DonySnackbarType.success` sauf
mention contraire.

## Intégration par flux

### A. Paiement confirmé (majeur)

Trois points d'entrée convergent vers `DonySuccessScreen(mascotteType: DonyMascotteType.securise, ...)`, gradient CTA bleu par défaut.

1. **`lib/features/payments/presentation/screens/payment_screen.dart:279-337`**
   `_EscrowConfirmedView` (widget privé) est supprimé ; son appelant construit
   `DonySuccessScreen(title: 'Envoi réservé !', subtitle: <texte existant>, ctaLabel: 'Voir mes envois', onCta: () => context.go('/home'))` à la place.

2. **`lib/features/matching/presentation/screens/create_bid_screen.dart:526-543`**
   et **`lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart:1211-1234`**
   Actuellement : la sheet `DonyPaymentSheet` affiche sa coche inline, se
   ferme après 900ms, puis navigue directement vers `/bids/{id}?from=payment`.
   Nouveau : après la fermeture de la sheet (garder les 900ms — c'est la
   micro-animation de la sheet elle-même, pas un auto-nav vers un écran
   final), pousser `DonySuccessScreen(title: 'Offre payée !', subtitle: 'Le voyageur va être notifié de ta demande.', ctaLabel: 'Voir mon envoi', onCta: () => context.go('/bids/$id?from=payment'))`
   au lieu de naviguer directement.

3. **`lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart:101-128`**
   et **`lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart`**
   Actuellement : sheet ferme, rien ne s'affiche, seul le `ThreadStateBanner`
   change d'état. Nouveau : après fermeture de la sheet, pousser
   `DonySuccessScreen(title: 'Offre acceptée et payée !', subtitle: 'Le voyageur est notifié, la livraison peut être suivie depuis le fil.', ctaLabel: 'Voir le suivi', onCta: () => context.go('/negotiations/$id'))`.

**Ne change pas :** `wallet_topup_amount_screen.dart:90-117` — recharge wallet
reste classée mineure, garde son `DonySnackbar` + `context.pop(true)` actuel
(déjà conforme au composant 2, à vérifier que l'appel utilise bien
`DonySnackbar.show` et pas un `ScaffoldMessenger` brut — sinon aligner).

### B. Trajet/annonce publié (majeur)

`mascotteType: DonyMascotteType.joyeux`, gradient CTA terracotta.

1. **`lib/features/matching/presentation/screens/create_trip_screen.dart:1191-1194`**

   **Contrainte découverte à l'investigation :** 5 call sites poussent cette
   route avec `await context.push<bool>('/trips/create', ...)`. 3 d'entre eux
   dépendent strictement du `bool` retourné pour rafraîchir leur état :
   - `announcement_list_screen.dart:148-153` (`_createTrip`)
   - `owner_action_grid.dart:118-127` (tuile "Modifier")
   - `trip_owner_detail_screen.dart:229-243` (`_onDepartureDatePassed`)

   Les 2 autres (`link_trip_screen.dart:288-309` et `:322-333`) ignorent déjà
   la valeur de retour et rafraîchissent sans condition ou via un
   `BlocListener<NegotiationBloc>` indépendant — ils ne cassent pas quel que
   soit le mécanisme choisi.

   **Solution retenue (pas de nouvelle mécanique de refresh, contrat `bool`
   préservé à l'identique) :** `create_trip_screen.dart` pousse
   `DonySuccessScreen` par-dessus lui-même (`Navigator.of(context).push`, pas
   de `pop` avant) avec :
   ```dart
   DonySuccessScreen(
     mascotteType: DonyMascotteType.joyeux,
     title: 'Trajet publié !',
     subtitle: 'Ton trajet <ville départ> → <ville arrivée> est en ligne.',
     ctaLabel: 'Voir mon trajet',
     onCta: () {
       Navigator.of(context).pop();       // ferme DonySuccessScreen
       Navigator.of(context).pop(true);   // ferme create_trip_screen — même valeur bool qu'avant, les 3 callers bool-dépendants continuent de fonctionner sans modification
       context.push('/trips/$tripId');    // puis ouvre le détail du trajet fraîchement créé
     },
   )
   ```
   Les 2 `pop` s'exécutent dans la même frame (pas de flash visuel de l'écran
   de succès qui se referme puis réapparaît) ; le `push` du détail suit
   immédiatement. Aucun des 5 call sites n'a besoin d'être modifié.

2. **`lib/features/matching/presentation/screens/create_announcement_screen.dart:571-579`**
   Remplace le `SnackBar` "Trajet publié !"/"Trajet modifié !" par le même
   `DonySuccessScreen` (titre adapté si édition : "Trajet modifié !").

3. **`lib/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart`**
   (lignes ~1095-1101, code mort) — fichier supprimé entièrement après
   confirmation qu'aucun call site ne subsiste (`grep -r CreateAnnouncementBottomSheet lib/`).

### C. Livraison confirmée (majeur)

**`lib/features/tracking/presentation/screens/scan_confirm_screen.dart:326-397`**

Remplace l'`AlertDialog` non-dismissible actuel par
`DonySuccessScreen(mascotteType: DonyMascotteType.securise, title: 'Colis livré !', subtitle: <texte existant>, ctaLabel: 'Terminer', onCta: () { RatingBottomSheet.show(...); })`
— le CTA "Terminer" déclenche la notation exactement comme aujourd'hui
(c'est l'action du bouton, pas un auto-nav par timer). Après fermeture de la
`RatingBottomSheet`, le flux existant vers `context.go('/tracking')` est
inchangé.

La variante offline "queued" (lignes 399-456, icône warning, pas de mascotte)
**ne change pas** — ce n'est pas un succès confirmé, c'est un état
intermédiaire différent, hors scope.

### D. Moments mineurs (SnackBar)

1. **`lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart:184-197`**
   Vérifier que le `SnackBar` "Offre envoyée" utilise déjà `DonySnackbar.show(type: success)` ; sinon migrer.

2. **`lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart:90-110`**
   Idem pour "Demande publiée — les voyageurs sont notifiés".

3. **`lib/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart:90-117`**
   Idem pour "Recharge réussie".

4. **`lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart`**
   branche non-checkout (acceptation cash, actuellement aucun feedback) —
   ajouter `DonySnackbar.show(type: DonySnackbarType.info, message: 'Offre acceptée — paiement en espèces à la remise')`.

## Gestion des erreurs

`DonySuccessScreen` ne s'affiche que lorsque l'action a déjà réussi côté
backend (paiement capturé, trajet créé, livraison confirmée par le
`DeliveryConfirmedEvent`) — les erreurs sont gérées en amont, dans le flux
existant (BLoC states d'erreur, `DonySnackbar.show(type: error)`), avant
d'atteindre l'écran de succès. Aucune gestion d'erreur nouvelle à l'intérieur
du composant lui-même.

## Tests

- **`dony_success_screen_test.dart`** (nouveau, voir Composant 1).
- Pour chacun des 6 sites majeurs migrés : test widget existant mis à jour
  pour vérifier que `DonySuccessScreen` apparaît avec le bon titre après
  l'action réussie (remplace les anciennes assertions sur `SnackBar`/pop
  silencieux/`AlertDialog`).
- Pour les 4 sites mineurs : test widget vérifiant `DonySnackbar` apparaît
  avec le bon message et `type`.
- `flutter analyze && flutter test` doivent rester verts, couverture ≥ 90 %
  sur les fichiers touchés (règle CLAUDE.md).

## Fichiers touchés (récapitulatif)

**Créés :**
- `lib/core/design/widgets/dony_success_screen.dart`
- `test/core/design/widgets/dony_success_screen_test.dart`

**Modifiés :**
- `lib/features/payments/presentation/screens/payment_screen.dart`
- `lib/features/matching/presentation/screens/create_bid_screen.dart`
- `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart`
- `lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart`
- `lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart`
- `lib/features/matching/presentation/screens/create_trip_screen.dart`
- `lib/features/matching/presentation/screens/create_announcement_screen.dart`
- `lib/features/tracking/presentation/screens/scan_confirm_screen.dart`
- `lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart`
- `lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart`
- `lib/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart`
- Tests widget correspondants pour chaque fichier ci-dessus

**Supprimés :**
- `lib/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart` (code mort)
- Test associé si présent
