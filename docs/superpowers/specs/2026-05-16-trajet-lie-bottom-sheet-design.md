# Design — Bottom sheet « Trajet lié » + refus de trajet

**Date :** 2026-05-16
**Projet :** dony_app (Flutter) — branche `refactor/details-trajet`
**Statut :** Validé, prêt pour le plan d'implémentation

## Contexte

Dans l'écran de négociation (`NegotiationThreadScreen`), une fois que le voyageur
a lié un trajet à l'offre acceptée, le thread passe au statut `AWAITING_PAYMENT`.
L'expéditeur voit alors le hero card violet « À RÉGLER » et le bouton « Payer ».

Aujourd'hui l'expéditeur n'a aucun moyen de consulter le détail du trajet auquel
son colis va être confié avant de payer. Cette feature ajoute :

1. Un bottom sheet « Trajet lié » ouvert au clic sur le hero card.
2. La possibilité, pour l'expéditeur, de refuser le trajet en donnant une raison.
3. Côté voyageur : voir la raison du refus et pouvoir proposer un autre trajet.

Une version antérieure de cette feature a existé sur la branche
`feat/negotiation-rework` (commit `9501730`) mais n'est pas présente sur la
branche courante. Le présent design la redéfinit avec le design visuel retenu
(timeline) et le flux de refus.

## Périmètre

**Backend — déjà implémenté, aucune modification :**

- `NegotiationThreadResponse.linkedTrip` : record `LinkedTripSummary`
  (`announcementId`, `departureCity`, `arrivalCity`, `departureDate`,
  `departureTime`, `transportMode`, `pickupAddressLabel`,
  `deliveryAddressLabel`, `availableKg`, `description`). `null` si aucun
  trajet n'est lié.
- `POST /api/v1/negotiations/{id}/refuse-trip` — corps `{ "reason": string }`
  (optionnel, max 280 caractères). Réservé à l'expéditeur, uniquement quand le
  thread est `AWAITING_PAYMENT` avec un trajet lié. Efface le trajet lié,
  repasse le thread en `AWAITING_TRIP`, persiste la raison comme message
  `NegotiationMessageKind.REJECT` (`body` = raison) et notifie le voyageur.

**Frontend — entièrement à implémenter** sur `refactor/details-trajet`.

Déclencheur d'ouverture du sheet : le hero card devient cliquable **uniquement**
quand toutes ces conditions sont réunies :

- `thread.status == NegotiationThreadStatus.awaitingPayment`
- le viewer est l'**expéditeur** (`thread.travelerId != viewerUserId`)
- `thread.linkedTrip != null`

Le sheet ne s'ouvre dans aucun autre état.

## Architecture

### Couche données

**Nouveau fichier — `lib/features/package_request/data/models/linked_trip_summary.dart`**

Modèle `LinkedTripSummary` mappant le record backend :

| Champ                  | Type      | Nullable |
|------------------------|-----------|----------|
| `announcementId`       | `String`  | non      |
| `departureCity`        | `String?` | oui      |
| `arrivalCity`          | `String?` | oui      |
| `departureDate`        | `String?` | oui (ISO `"2026-06-12"`) |
| `departureTime`        | `String?` | oui (`"14:30"`) |
| `transportMode`        | `String?` | oui (`"PLANE"` / `"TRAIN"` / `"CAR"`) |
| `pickupAddressLabel`   | `String?` | oui      |
| `deliveryAddressLabel` | `String?` | oui      |
| `availableKg`          | `int?`    | oui      |
| `description`          | `String?` | oui      |

`factory LinkedTripSummary.fromJson(Map<String, dynamic>)`. Étend `Equatable`.

**Modifié — `lib/features/package_request/data/models/negotiation_thread.dart`**

- Nouveau champ `final LinkedTripSummary? linkedTrip;`
- Constructeur : paramètre optionnel `this.linkedTrip`.
- `fromJson` : `linkedTrip: json['linkedTrip'] == null ? null :
  LinkedTripSummary.fromJson(json['linkedTrip'] as Map<String, dynamic>)`
- Ajouté à `props`.

**Modifié — `lib/features/package_request/data/negotiation_repository.dart`**

Nouvelle méthode :

```dart
Future<NegotiationThread> refuseTrip(String id, {String? reason}) async {
  final res = await _dio.post(
    '/negotiations/$id/refuse-trip',
    data: reason == null ? null : {'reason': reason},
  );
  return NegotiationThread.fromJson(res.data as Map<String, dynamic>);
}
```

(Aligné sur le style de `submitTrip` dans le même fichier.)

### Couche BLoC

**Modifié — `lib/features/package_request/bloc/negotiation_bloc.dart`**

- Nouvel event `NegotiationRefuseTripRequested` :
  ```dart
  class NegotiationRefuseTripRequested extends NegotiationEvent {
    const NegotiationRefuseTripRequested({required this.threadId, this.reason});
    final String threadId;
    final String? reason;
  }
  ```
- Enregistrement `on<NegotiationRefuseTripRequested>(_onRefuseTrip);`
- Handler `_onRefuseTrip`, calqué sur `_onSubmitTrip` : émet
  `NegotiationActionInProgress` (si état courant `NegotiationLoaded`) sinon
  `NegotiationLoading`, appelle `_repository.refuseTrip(...)`, émet
  `NegotiationLoaded(thread)` en cas de succès ou
  `NegotiationError(unwrapDioError(err))` en cas d'échec.

### Couche présentation

**Nouveau — `lib/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart`**

`TripDetailBottomSheet` — design « timeline » :

- Méthode statique `show(BuildContext, { required LinkedTripSummary trip,
  required bool isSender, required NegotiationBloc bloc, required String
  threadId })`.
- `DonyBottomSheet.show`, titre `'Trajet lié'`.
- `child` :
  - Rangée de chips : mode de transport (icône + libellé), `availableKg`,
    date de départ. Chaque chip n'est rendu que si la donnée est présente.
  - Timeline verticale : point plein « DÉPART » (+ heure si présente) →
    ligne → cercle « ARRIVÉE ». Sous chaque ville, l'adresse correspondante
    (`pickupAddressLabel` / `deliveryAddressLabel`) si présente.
  - Encart « Note du voyageur » avec `description` si non vide.
- `stickyBottom` (uniquement si `isSender == true`) :
  `DonyButton('Refuser le trajet', variant: DonyButtonVariant.destructive)`.
  Au tap : fermer ce sheet (`Navigator.pop` root) puis ouvrir
  `RefuseTripBottomSheet`.
- Si `isSender == false`, pas de `stickyBottom` (lecture seule).
- Mode de transport → icône : `PLANE` ✈️, `TRAIN` 🚄, `CAR` 🚗, défaut 📦.
- Formatage de date : ISO → « 12 juin 2026 » (jour + mois abrégé + année).
- Respecte les tokens du design system (`DonySpacing`, `DonyRadius`,
  `DonyColors`), `fontSize` minimum 12.

**Nouveau — `lib/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart`**

`RefuseTripBottomSheet` — sheet de saisie de la raison :

- Méthode statique `show(BuildContext, { required NegotiationBloc bloc,
  required String threadId })`.
- `DonyBottomSheet.show`, titre `'Refuser ce trajet'`,
  `wrapper: (child) => BlocProvider.value(value: bloc, child: child)`.
- `child` : texte explicatif + `TextField` (raison, `maxLines: 3`,
  `maxLength: 280`).
- Raison **obligatoire** : le bouton de confirmation est désactivé tant que le
  champ est vide. Pattern du CLAUDE.md « Bouton dépend d'état + BLoC » —
  `ValueNotifier<bool>` mis à jour par un listener du `TextEditingController`,
  combiné `ValueListenableBuilder` → `BlocBuilder` dans `stickyBottom`.
  Le `ValueNotifier` est disposé via `.whenComplete(notifier.dispose)`.
- `stickyBottom` : `DonyButton('Confirmer le refus', destructive)`,
  `isLoading` quand l'état est `NegotiationActionInProgress` /
  `NegotiationLoading`, `onPressed` désactivé si vide ou en cours.
- Au submit : `bloc.add(NegotiationRefuseTripRequested(threadId: ...,
  reason: <texte trimé>))` puis fermeture du sheet.

**Modifié — `lib/features/package_request/presentation/widgets/thread/thread_hero_card.dart`**

- `ThreadHeroCard` reçoit un nouveau paramètre optionnel
  `final VoidCallback? onTap;`.
- Si `onTap != null` : le contenu est enveloppé dans un `InkWell` (ou
  `GestureDetector`) et un indicateur visuel est ajouté en bas du card —
  une rangée discrète « Voir le trajet lié » + chevron `›`, en blanc semi-
  transparent, cohérente avec le style du hero card.
- Si `onTap == null` : rendu inchangé (aucune affordance).

**Modifié — `lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart`**

Dans `_LoadedView.build` :

- Calculer `isSender = thread.travelerId != viewerUserId`.
- Construire `onTap` du hero card :
  ```dart
  final canViewTrip = thread.status == NegotiationThreadStatus.awaitingPayment
      && isSender
      && thread.linkedTrip != null;
  ```
  Si `canViewTrip`, passer `onTap: () => TripDetailBottomSheet.show(context,
  trip: thread.linkedTrip!, isSender: true,
  bloc: context.read<NegotiationBloc>(), threadId: thread.id)` ; sinon `null`.

**Modifié — `lib/features/package_request/presentation/widgets/thread/thread_message_bubble.dart`**

- `ThreadMessageBubble` reçoit un nouveau paramètre `final bool isTripRefusal;`
  (défaut `false`).
- Quand `isTripRefusal == true`, le message est rendu comme un **bandeau
  rouge clair** pleine largeur — fond rouge pâle, bordure rouge, titre
  « ⚠️ Trajet refusé par l'expéditeur » + le `body` (la raison) entre
  guillemets — au lieu de la bulle « REJETÉE » standard.
- `_LoadedView` calcule le flag par message :
  ```dart
  final isTripRefusal = m.kind == NegotiationMessageKind.reject
      && thread.status != NegotiationThreadStatus.rejected
      && thread.status != NegotiationThreadStatus.autoRejected;
  ```
  Heuristique : un message `REJECT` dans un thread **non terminal** est un
  refus de trajet ; un `REJECT` dans un thread `rejected`/`autoRejected` est
  un rejet de négociation (rendu « REJETÉE » classique).

## Flux utilisateur

### Refus du trajet (expéditeur)

1. Thread `AWAITING_PAYMENT`, expéditeur, trajet lié → hero card cliquable.
2. Tap sur le hero card → `TripDetailBottomSheet` (timeline + bouton
   « Refuser le trajet »).
3. Tap « Refuser le trajet » → fermeture du sheet trajet → ouverture de
   `RefuseTripBottomSheet`.
4. Saisie de la raison (obligatoire) → « Confirmer le refus ».
5. `NegotiationRefuseTripRequested` → `refuseTrip` → backend efface le trajet,
   repasse en `AWAITING_TRIP`, persiste la raison comme message `REJECT`.
6. `NegotiationLoaded(thread)` ré-émis → l'UI repasse en état `AWAITING_TRIP`.

### Côté voyageur

1. Le voyageur ouvre le thread (statut `AWAITING_TRIP`).
2. Le message `REJECT` portant la raison s'affiche comme bandeau
   « Trajet refusé par l'expéditeur » dans la conversation.
3. Le CTA « Lier un trajet à cette offre » (déjà existant au statut
   `AWAITING_TRIP`, côté voyageur) lui permet de proposer un autre trajet.

## Gestion des erreurs

- Échec réseau de `refuseTrip` → `NegotiationError` → `ErrorPresenter.show`
  (listener déjà en place dans `_ThreadView`).
- Conflits backend (`409 thread/not-awaiting-payment`, `thread/no-trip-linked`)
  remontés via le même mécanisme RFC 7807 → `unwrapDioError`.
- `linkedTrip` absent alors que le statut est `AWAITING_PAYMENT` : le hero card
  reste non cliquable (condition `thread.linkedTrip != null`).
- Champs nullable de `LinkedTripSummary` : chaque section du sheet n'est rendue
  que si sa donnée est présente.

## Tests

Cible : couverture ≥ 90 % (règle projet).

- **Modèle** — `negotiation_thread_test.dart` : parsing de `linkedTrip`
  présent / absent ; `linked_trip_summary_test.dart` : `fromJson` complet et
  avec champs nullables.
- **Repository** — `refuseTrip` : appel `POST` avec et sans `reason`,
  désérialisation de la réponse.
- **BLoC** — `NegotiationRefuseTripRequested` : succès (→ `NegotiationLoaded`),
  échec (→ `NegotiationError`), émission de `NegotiationActionInProgress`.
- **Widgets** :
  - `TripDetailBottomSheet` : affichage des sections, présence du bouton
    « Refuser le trajet » côté expéditeur, absence côté voyageur, gestion des
    champs nullables.
  - `RefuseTripBottomSheet` : bouton désactivé si raison vide, activé sinon ;
    dispatch de l'event au submit.
  - `ThreadHeroCard` : affordance « Voir le trajet lié » présente si
    `onTap != null`, absente sinon.
  - `negotiation_thread_screen` : hero card cliquable seulement si
    `AWAITING_PAYMENT` + expéditeur + `linkedTrip != null`.
  - `ThreadMessageBubble` : rendu bandeau « Trajet refusé » si
    `isTripRefusal`, rendu « REJETÉE » sinon.

## Décisions techniques

- **Raison obligatoire** (et non optionnelle, bien que le backend l'accepte
  `null`) : l'intérêt de la feature est que le voyageur comprenne pourquoi son
  trajet est refusé pour en proposer un meilleur. Le bouton reste désactivé
  tant que le champ est vide.
- **Distinction refus de trajet / rejet de négociation** : le backend réutilise
  `NegotiationMessageKind.REJECT` pour les deux. Faute d'un type dédié, le front
  les distingue par le statut du thread (non terminal = refus de trajet). C'est
  une heuristique : si une évolution backend introduit un type de message dédié,
  ce flag devra être recâblé dessus.
- **Design « timeline »** retenu (vs liste détaillée ou style billet) pour la
  lisibilité de l'itinéraire départ → arrivée.
- **Réutilisation du CTA existant** « Lier un trajet à cette offre » pour la
  re-proposition côté voyageur — aucun nouveau composant nécessaire, le retour
  en `AWAITING_TRIP` réactive le CTA déjà en place.
