# Écran « Mes litiges » — Design

**Date :** 2026-07-15
**Statut :** validé (maquette : https://claude.ai/code/artifact/a612432c-c48b-40ac-889c-8d240da896cd)
**Portée :** dony_app (feature complète) + dony-back (extension endpoint)

## Contexte

L'entrée « Mes litiges » du profil (onglet Activité, section SUIVI) pointe sur
`/disputes`, aujourd'hui un `_PlaceholderScreen` vide. Côté backend la feature
existe : un litige naît uniquement quand l'expéditeur **conteste un no-show**
(`CancellationService` → `DisputeOpenedEvent` → `DisputeService.openSenderNoShowDispute`,
type `SENDER_NO_SHOW_CONTESTED`, statut `OPEN`, `refundFrozen=true`), et se résout
uniquement côté admin (dony-admin : `resolve` avec note, ou `guarantee-fund` →
`GUARANTEE_PAID` + montant + bénéficiaire).

**Bug backend au passage :** `GET /disputes/me` est `@PreAuthorize("hasRole('TRAVELER')")`
alors que le litige est ouvert par l'expéditeur — le sender ne peut voir aucun de
ses litiges. À corriger dans cette feature.

## Décisions de scope (validées)

- **Suivi seul** : liste + détail, lecture seule, pour les deux rôles (sender ET traveler).
- **Pas de création** de litige depuis cet écran — la création reste dans le flux
  contestation no-show existant. L'empty state l'explique.
- **Pas d'échanges/preuves** avec l'admin (hors scope).

## Backend (dony-back)

### 1. `DisputeResponse` enrichi

Le DTO actuel (`id, bidId, type, status, refundFrozen, createdAt`) ne permet pas
d'afficher un écran lisible. Nouveau DTO :

```
id, bidId, type, status, refundFrozen, createdAt,
myRole            // "SENDER" | "TRAVELER" — rôle de l'appelant dans CE litige
otherPartyName    // nom affichable de l'autre partie (pattern MatchingTextUtil.buildName)
departureCity, arrivalCity, departureCountryCode, arrivalCountryCode
tripDate          // date de départ de l'annonce
weightKg          // poids du bid
resolutionType, resolvedAt, resolutionNote,
guaranteeAmountCents, isBeneficiary  // true si beneficiaryUserId == appelant
```

Contexte joint via `bidId` → `BidEntity` → `AnnouncementEntity` (batch, pattern
identique à `AdminDisputesController` : collecter les IDs, `findAllById`, mapper).
Si le bid ou l'annonce a été soft-deleted → champs contexte à `null`, le front
affiche « Envoi supprimé ».

### 2. `GET /disputes/me` ouvert aux deux rôles

- `@PreAuthorize("hasAnyRole('SENDER','TRAVELER')")`
- Requête union : `WHERE (sender_id = :me OR traveler_id = :me) ORDER BY created_at DESC`
  (nouvelle méthode repository ; l'ancienne `findByTravelerIdOrderByCreatedAtDesc`
  peut être supprimée si plus utilisée).
- `myRole` déduit par litige (l'appelant peut être sender d'un litige et traveler d'un autre).

Pas de pagination : volumétrie très faible par utilisateur (litiges = événements rares).

### 3. Tests

- `DisputeServiceTest` : union sender/traveler, mapping contexte, bid/annonce absents,
  `isBeneficiary` vrai/faux, ordre par date.
- `DisputeControllerTest` : accès SENDER accepté, TRAVELER accepté, 401 sans token.

## Flutter (dony_app)

Nouvelle feature `lib/features/disputes/` — structure standard `bloc/ + data/ + presentation/`.

### Data

- `DisputeModel` : miroir du DTO enrichi, `fromJson`.
- `DisputeRepository` + `DisputeRemoteDatasource` : `GET /disputes/me` via `ApiClient` (Dio).
- DI : `registerLazySingleton` datasource/repository, `registerFactory` bloc (avec `AnalyticsService`).

### BLoC

- `DisputeListBloc` : event `DisputesLoadRequested` → states `DisputeListInitial / Loading / Loaded(List<DisputeModel>) / Error(AppException)`.
- Pas de bloc détail : le détail reçoit le `DisputeModel` via `extra` (les données
  sont déjà complètes dans la liste ; pas d'endpoint détail).

### Écrans

**1. Liste (`/disputes`, remplace le placeholder)**
- AppBar back + « Mes litiges ».
- Cards triées récent d'abord :
  - type traduit (« Contestation no-show » ; fallback : type brut),
  - badge statut : chip amber « En instruction » (OPEN) / chip verte « Résolu » (RESOLVED),
  - corridor drapeaux + villes (comme les cards trajet existantes),
  - autre partie préfixée selon `myRole` (« Voyageur : Awa K. » / « Expéditeur : … »),
  - poids, dates (ouvert le X ; résolu le Y si résolu),
  - bandeau info bleu « Remboursement gelé le temps de l'instruction — réponse sous 72 h »
    si `refundFrozen && status == OPEN`.
- Tap card → `context.push('/disputes/detail', extra: dispute)`.
- Pull-to-refresh → `DisputesLoadRequested`.
- Loading / Error (avec « Réessayer ») / Empty gérés.

**2. Détail (`/disputes/detail`)**
- Head-card : type + chip statut + corridor + autre partie + poids.
- Si OPEN + refundFrozen : bandeau gel sous la head-card.
- Timeline 3 étapes : « Litige ouvert » (done, date) → « En instruction »
  (done si résolu, sinon point amber actif) → « Décision » (verte + date si résolu,
  sinon grisée « sous 72 h »).
- Si RESOLVED : bloc « Décision » à liseré vert — verdict (« Résolu en votre faveur »
  si `isBeneficiary`, sinon « Litige résolu »), `resolutionNote` de l'admin,
  ligne « Indemnisation versée : X,XX € » seulement si `GUARANTEE_PAID && isBeneficiary`.
- CTA « Contacter le support » → `/profile/help/contact`.

**3. Empty state**
- Glyphe balance, « Aucun litige », texte pédagogique : « Un litige s'ouvre
  automatiquement si vous contestez l'absence d'un voyageur lors d'une remise. »
- CTA « Un problème avec un envoi ? » → `/profile/help/contact`.

### Router

- `/disputes` → `DisputeListScreen` sous `BlocProvider(getIt<DisputeListBloc>()..add(DisputesLoadRequested()))`.
- `/disputes/detail` → `DisputeDetailScreen(dispute: state.extra)`.
- Écran lecture seule → pas de pattern refresh-après-navigation nécessaire.

### Analytics

- `disputes_opened` : `DisputeListBloc` au premier `Loaded` (propriété `count`).
- `dispute_detail_opened` : ouverture du détail (propriété `status`).
- Noms déclarés dans `AnalyticsEvents`, tirés dans le BLoC, `unawaited`, pas de PII.
- Table des events de `dony_app/CLAUDE.md` mise à jour.

### Tests

- `dispute_model_test` : fromJson complet + champs contexte null.
- `dispute_list_bloc_test` (blocTest) : loading→loaded, erreur, analytics tiré une fois.
- Widget tests : liste (cards, badges, bandeau gel conditionnel), détail résolu
  (décision, montant conditionnel `isBeneficiary`), détail en cours (étape grisée),
  empty state, navigation tap card → détail.
- Couverture ≥ 90 % sur la feature.

## Traductions statuts/résolutions (front)

| Valeur backend | Affichage |
|---|---|
| `SENDER_NO_SHOW_CONTESTED` | Contestation no-show |
| `OPEN` | En instruction |
| `RESOLVED` | Résolu |
| `GUARANTEE_PAID` | Indemnisation versée |
| autre `resolutionType` | affiché tel quel dans le bloc décision (note admin prime) |

## Hors scope (explicitement)

- Création de litige depuis l'app.
- Fil d'échanges / upload de preuves.
- Notifications push à la résolution (le backend ne notifie pas aujourd'hui — piste future).
- Pagination de la liste.
