# Redesign « Activités » — Mes trajets & hub Envoyer

**Date :** 2026-06-10 · **Statut :** validé en brainstorming visuel (mockups : `.superpowers/brainstorm/72571-1781047969/content/`)

## Contexte

Les écrans « Mes trajets » (voyageur) et « Envoyer » (expéditeur) manquent de vie : hiérarchie plate, onglets lourds, cartes sans narration. Redesign validé écran par écran avec le compagnon visuel.

**Direction retenue : A — « Éditorial calme »** : palette actuelle (bleu `#0B5FFF`, terracotta, sand), la vie vient des micro-animations et de la narration des cartes, pas de couleurs criardes.

## Périmètre

1. Écran `AnnouncementListScreen` (« Mes trajets ») — restructuration complète.
2. Écran `EnvoyerHubScreen` + `ShipmentListScreen` (onglet Envois) — restructuration complète.
3. Renommage onglet bottom nav « Annonces » → « Activités » (`main_shell.dart`).
4. Backend : nouvel endpoint `GET /travelers/me/trips-summary`.

**Hors scope :** onglet Demandes (`MyPackageRequestsScreen`) — garde sa liste actuelle mais hérite du nouveau header/segmented du hub ; écrans de détail ; dark mode raffiné (les composants utilisent `cs.X`, donc compatible par construction).

## Logique de rôles (inchangée)

`annoncesLayoutFor()` reste la source de vérité :
- `senderOnly` (rôle SENDER uniquement) → **`EnvoyerHubScreen` seul**, sans pill « ✈️ Mes trajets ».
- `occasionalTraveler` → `EnvoyerHubScreen` + pill « ✈️ Mes trajets » dans le header.
- `proTraveler` → `AnnouncementListScreen` + pill « 📦 Envoyer » dans le header.

Les pills header remplacent l'actuel `SecondaryActivityEntry` (widget conservé ailleurs si utilisé, sinon supprimé).

---

## Écran « Mes trajets » (`AnnouncementListScreen`)

### Structure (haut → bas)

1. **Header** : titre « Mes trajets » (Hanken Grotesk, `headlineLarge`+) ; à droite : pill sand/terracotta « 📦 Envoyer » (`surfaceWarm` fond, texte `terra600`, visible si `onSendParcel != null`) + pill bleue « + Nouveau » (`primary`).
2. **Bandeau mini-stats** : 3 tuiles (`DonyCard` compactes) — *Trajets actifs* (valeur bleue), *Kg vendus ce mois*, *Revenus ce mois* (valeur terracotta). Source : endpoint `trips-summary`. Si l'appel échoue → bandeau masqué (pas de skeleton persistant).
3. **Recherche** : champ pill « Rechercher une destination… » — filtre local sur `departureCity`/`arrivalCity`.
4. **Chips statut (pattern Airbnb)** : rangée scrollable horizontale — `Tous · n` / `● Actifs · n` (point `success500`) / `● Terminés · n` (point `neutral500`) / `● Annulés` (point `danger500`). Chip active : fond `ink800`, texte blanc. **Remplace les 3 onglets À venir/Historique/Annulés.**
5. **Liste unique** : par défaut « Tous », triée statut (IN_PROGRESS/ACTIVE d'abord) puis date. Cartes terminées/annulées : opacité ~0.65, badge gris, footer condensé (« 20 kg vendus · 160 € gagnés »).

Mapping statuts : Actifs = `ACTIVE` + `FULL` + `IN_PROGRESS` ; Terminés = `COMPLETED` ; Annulés = `CANCELLED`.

### Carte trajet (remplace `_AnnouncementCard`)

Nouveau widget partagé `TripCard` (`lib/features/matching/presentation/widgets/trip_card.dart`) :

- **Ligne 1** : route « Paris ⟶ Dakar » (Hanken Grotesk w800, flèche `primary`) + badge statut à droite. Badge ACTIF : fond `success50`, texte `success500`, **point pulsant** (animation opacity loop ~1,2 s).
- **Ligne 2** : méta « Départ dans 3 jours · 18 juin » (`textMuted`).
- **Timeline de vol** : drapeau emoji pays départ — ligne pointillée (`blue200`) avec ✈️ (icône Material `flight` ou emoji) posé dessus — drapeau pays arrivée. Drapeaux dérivés d'une table statique ville→drapeau couvrant les corridors dony (Paris/Lyon/Marseille → 🇫🇷 ; Dakar 🇸🇳, Abidjan 🇨🇮, Bamako 🇲🇱, Douala 🇨🇲…) ; ville inconnue → point bleu par défaut (pas d'emoji cassé).
- **Progression** : barre fine 4 px (`primary` sur `neutral100`) = kg vendus / kg total (`(totalKg - availableKg) / totalKg`), label « 7 kg vendus sur 20 kg ».
- **Footer** (séparé par divider) : « **13 kg** disponibles » à gauche, prix « 8 € /kg » (Hanken Grotesk w800) à droite.
- Carte tappable entière → détail (comportement actuel conservé).

### Bottom sheet « Afficher » — abandonné

Le sélecteur bottom sheet (exploré en mockup) est remplacé par les chips Airbnb — décision finale.

---

## Hub « Envoyer » (`EnvoyerHubScreen` + `ShipmentListScreen`)

### Structure

1. **Header** : titre « Envoyer » ; à droite : pill bleu clair « ✈️ Mes trajets » (`primarySoft` fond, texte `primaryHover` — uniquement layouts `occasionalTraveler`) + pill « + Nouveau ».
2. **Segmented glissant** Envois/Demandes : fond `neutral100`, capsule blanche qui glisse (animation spring ~250 ms), compteurs bleus. Remplace `_EnvoyerSegmented`.
3. **Onglet Envois** : recherche pill (mêmes champs qu'aujourd'hui : ville, destinataire, voyageur, tracking) + **chips statut colorés** : `Tous` / `● En transit` (info500) / `● En attente` (warning500) / `● Livrés` (success500). Mapping sur les groupes existants de `ShipmentFilterCubit` : En transit = `kEnvoisEnCours`, En attente = `kEnvoisAVenir`, Livrés = `{COMPLETED}` uniquement. Les autres statuts passés (REJECTED, CANCELLED, NO_SHOW, EXPIRED, PARCEL_REFUSED) restent visibles via « Tous ». Le filtre Période existant reste accessible (icône réglages en bout de rangée de chips).
4. **Liste cartes envoi** (nouveau widget `ShipmentCard`).

### Carte envoi (`ShipmentCard`)

- **Ligne 1** : route + badge statut coloré (EN TRANSIT `info50/info700`, EN ATTENTE `warning50/warning700`, LIVRÉ `success50/success500`…).
- **Ligne 2** : « Colis 4,5 kg · pour {destinataire} ».
- **Stepper d'étapes** : 4 pastilles rondes avec **icônes Material** (check / colis / avion / maison) reliées par segments — remplies `primary` si franchies, `primarySoft` étape courante, `neutral100` à venir. Libellé sous le stepper : « Remis → Embarqué → **En vol vers Dakar** → Livraison » (étape courante en gras coloré). Mapping étapes ← `BidStatus` : ACCEPTED=1, HANDED_OVER=2, IN_TRANSIT=3, COMPLETED=4 ; statuts pré-acceptation (PENDING, AWAITING_PAYMENT, PAYMENT_ESCROWED) : pas de stepper, ligne d'attente à la place.
- **Footer** : avatar + nom voyageur à gauche ; lien « Suivre le colis → » / « Voir le QR → » selon statut à droite.
- Icônes : **Material icons dans pastilles** (pas d'emoji) pour le stepper ; emojis conservés uniquement pour les drapeaux.

### État vide (onglet Envois)

`DonyEmptyState` enrichi : `DonyMascotteAnimated(type: assis)` sur pastille dégradée `blue50 → sand100`, titre « Aucun envoi pour l'instant », description, CTA pill « 🔍 Rechercher un trajet » avec ombre portée (`primary` @ 30 %), lien secondaire « ou publie une demande de transport → » (bascule vers l'onglet Demandes). Recherche + chips **masquées** quand la liste brute est vide.

---

## Bottom nav

`main_shell.dart` : label onglet index 1 « Annonces » → **« Activités »**. Icône inchangée. Vérifier tout libellé/tooltip/Semantics associé.

---

## Backend — `GET /travelers/me/trips-summary`

Nouveau, package `matching/` (pattern copié de `TravelerStatsController`) :

- **Auth** : `Role.TRAVELER` requis, **sans** gate `isProAccount()` (contrairement à `/travelers/me/stats`).
- **DTO** `TripsSummaryDto` (record) : `long activeTrips`, `BigDecimal kgSoldThisMonth`, `BigDecimal revenueThisMonth`.
- **Calculs** :
  - `activeTrips` = `announcementRepository.countByTravelerIdAndStatus(id, ACTIVE)` (+ FULL + IN_PROGRESS — nouvelle query `countByTravelerIdAndStatusIn`).
  - `revenueThisMonth` = `paymentRepository.sumCapturedRevenueForTraveler(id, RELEASED, monthStart, now)` (existant).
  - `kgSoldThisMonth` = nouvelle query : `SUM(bid.weightKg)` des bids `COMPLETED` du mois joints aux annonces du voyageur.
- **Cache** : `@Cacheable` Caffeine, TTL 5 min (cache name dédié dans `CacheConfig`).
- Erreurs RFC 7807 via `GlobalExceptionHandler` (rien de spécifique).

Côté Flutter : `MatchingRepository.getTripsSummary()` + modèle `TripsSummaryModel` ; chargé par le BLoC de l'écran (event `TripsSummaryRequested`), état séparé pour ne pas bloquer la liste.

## Animations (flutter_animate, direction A)

- Entrée cartes : fadeIn + slideY 0.04, stagger 60 ms × index, 300 ms easeOutCubic.
- Badge ACTIF : point pulsant en boucle.
- Segmented : capsule glissante (AnimatedAlign/`TweenAnimationBuilder`, ~250 ms).
- Barres de progression : largeur animée à l'apparition (400 ms easeOutCubic).
- Chips : changement de sélection animé (AnimatedContainer 150 ms).
- Stats : compteur sans animation (sobriété) — apparition avec le reste du header.

## Analytics

- Screens : routes inchangées → tracking auto conservé.
- `shipment_filter_applied` : conservé (chips Envois passent par `ShipmentFilterCubit`).
- **Nouveau** `trip_filter_applied` (chips statut Mes trajets) — propriété `status`, déclaré dans `AnalyticsEvents`, tiré dans le BLoC/cubit.
- `envoyer_envois` / `envoyer_demandes` : conservés (segmented).
- Aucune PII (statuts seulement).

## Tests

- **Flutter** : tests widgets `TripCard`, `ShipmentCard`, chips de filtres, état vide ; tests BLoC/cubit pour `TripsSummary` et le filtre statut trajets ; mise à jour des tests existants (`ShipmentFilterCubit` inchangé). Couverture ≥ 90 %.
- **Back** : unit tests `TripsSummaryService` (calculs, mois courant, voyageur sans données) + MockMvc `TripsSummaryController` (200, 403 non-voyageur). Couverture ≥ 90 %.

## Décisions actées (historique brainstorming)

| Question | Choix |
|---|---|
| Direction visuelle | A — Éditorial calme (+ drapeaux) |
| Drapeaux | Sur la timeline de vol (pas dans le titre) |
| Structure Mes trajets | V2 avec mini-stats |
| Navigation statuts | Chips colorés type Airbnb (liste unique « Tous ») |
| Accès expéditeur | Pill « 📦 Envoyer » dans le header |
| Hub Envoyer | Segmented Envois/Demandes + chips statut + stepper colis |
| Iconographie | Material icons en pastilles ; emojis pour drapeaux uniquement |
| Onglet bottom nav | « Annonces » → « Activités » |
| Rôle expéditeur seul | `EnvoyerHubScreen` uniquement (comportement `annoncesLayoutFor` conservé) |
| Stats indisponibles | Bandeau masqué ; endpoint dédié créé côté back |
