# Story — Redesign « Activités » (Mes trajets + hub Envoyer)

**Date :** 2026-06-10 | **Status :** ✅ Complète

## Résumé

Redesign moderne et fluide des deux écrans de l'onglet bottom nav renommé **« Annonces » → « Activités »** :
- **Mes trajets** (voyageur) : header à pills, bandeau de 3 mini-stats, recherche, navigation par **chips statut colorés** (pattern Airbnb, fini les onglets), cartes trajet `TripCard` avec timeline de vol à drapeaux, badge pulsant et barre de progression kg animée.
- **Hub Envoyer** (expéditeur) : header symétrique, **segmented glissant** Envois/Demandes, chips statut, cartes envoi `ShipmentCard` avec **stepper colis 4 étapes**, état vide à mascotte.

Direction visuelle retenue : « Éditorial calme » — palette dony existante (bleu `#0B5FFF`, terracotta, sand), la vie vient des micro-animations (flutter_animate) et de la narration des cartes.

Nouvel endpoint backend `GET /travelers/me/trips-summary` (tout voyageur, sans gate Pro) alimentant le bandeau stats.

## Fichiers créés / modifiés

### Backend (`dony-back`, branche `feature/trips-summary-endpoint`)
- `matching/AnnouncementRepository.java` — `countByTravelerIdAndStatusIn`.
- `matching/BidRepository.java` — `sumDeliveredKgForTraveler` (COALESCE SUM weightKg, garde soft-delete).
- `matching/dto/TripsSummaryDto.java` — record (activeTrips, kgSoldThisMonth, revenueThisMonth).
- `matching/TripsSummaryService.java` — `@Cacheable("trips-summary")`, calcul mois courant.
- `matching/TripsSummaryController.java` — `GET /travelers/me/trips-summary`, guard `Role.TRAVELER` (pas de Pro), 403 sinon.
- `config/CacheConfig.java` — cache `trips-summary` (Caffeine 5 min).
- Tests : `TripsSummaryRepositoryIT`, `TripsSummaryServiceTest`, `TripsSummaryControllerTest`.

### Flutter (`dony_app`, branche `feature/redesign-activites-envoyer`)
**Créés :**
- `matching/data/models/trips_summary_model.dart`
- `matching/bloc/trips_summary_cubit.dart` — états initial/loading/loaded/hidden (erreur → bandeau masqué).
- `matching/bloc/trip_filter_cubit.dart` — `TripStatusFilter{all,active,completed,cancelled}`, `matchesStatus`/`matchesQuery`, event `trip_filter_applied`.
- `matching/presentation/utils/city_flags.dart` — mapping ville→drapeau emoji (corridors dony).
- `matching/presentation/widgets/trip_card.dart` — `TripCard` + sous-widgets (timeline, badge pulsant, stepper kg).
- `matching/presentation/widgets/activity_header_widgets.dart` — `HeaderPill`, `TripsStatsStrip`, `StatusChipsRow<T>`, `ActivitySearchField`.
- `matching/presentation/widgets/shipment_card.dart` — `ShipmentCard` + `ShipmentStepper` + `shipmentStepFor`.

**Modifiés :**
- `matching/data/datasources/announcement_remote_datasource.dart` + `repositories/announcement_repository.dart` — `getTripsSummary()`.
- `matching/presentation/screens/announcement_list_screen.dart` — réécriture complète (suppression onglets/_AnnouncementCard).
- `matching/presentation/screens/matching_management_screen.dart` — providers `TripsSummaryCubit` + `TripFilterCubit` (branche proTraveler).
- `matching/presentation/screens/shipment_list_screen.dart` — chips statut + `ShipmentCard` + empty state.
- `package_request/presentation/screens/sender/envoyer_hub_screen.dart` — header pills + segmented glissant.
- `core/services/analytics_events.dart` — `tripFilterApplied`.
- `core/di/injection.dart` — enregistrement des 2 cubits.
- `app/main_shell.dart` — label onglet « Activités ».

## Comment ça fonctionne

### Flux utilisateur
- **Voyageur (proTraveler)** ouvre l'onglet Activités → `AnnouncementListScreen`. Au montage : `AnnouncementListRequested` (liste) + `TripsSummaryCubit.load()` (stats). Il voit le bandeau stats (si chargé), une recherche, des chips Tous/Actifs/Terminés/Annulés, et la liste unifiée de `TripCard` (en cours/actifs en tête, passés grisés). Pull-to-refresh recharge liste **et** stats. Pill « 📦 Envoyer » bascule côté expéditeur.
- **Expéditeur (senderOnly)** voit uniquement le hub `EnvoyerHubScreen` (pas de pill « Mes trajets »). Segmented Envois/Demandes, chips statut (En transit/En attente/Livrés), cartes `ShipmentCard` avec stepper colis. État vide à mascotte → CTA « Rechercher un trajet » + lien vers Demandes.
- **occasionalTraveler** : hub Envoyer + pill « ✈️ Mes trajets ».

### BLoC / cubits
- `TripsSummaryCubit.load()` : `loading` → `loaded(summary)` ou `hidden` (toute erreur ⇒ bandeau masqué, jamais d'état d'erreur). Le bandeau n'apparaît qu'en `loaded`.
- `TripFilterCubit` : `setFilter` (émet + log `trip_filter_applied {status}`), `setQuery` (émet sans log). Le filtrage est local (`matchesStatus && matchesQuery`). Re-tap de la chip active : l'écran ne rappelle pas `setFilter` (anti-bruit analytics).
- Filtrage Envois : réutilise `ShipmentFilterCubit` (les chips mappent les groupes `kEnvoisEnCours`/`kEnvoisAVenir`/`{COMPLETED}` via `applyQuickPreset`, comparaison `setEquals`).

### Écrans / widgets clés
- `TripCard` : route (Hanken Grotesk + flèche), badge statut (point pulsant si actif), timeline drapeaux (CustomPainter pointillé + avion), progression kg animée (`TweenAnimationBuilder`), footer kg dispo + prix. Passés : grisés, footer condensé + gains. Entrée fadeIn+slideY staggered.
- `ShipmentCard` : `ShipmentStepper` 4 pastilles (icônes Material) mappé sur `BidStatus` (ACCEPTED=1…COMPLETED=4 ; pré-acceptation = pas de stepper), CTA contextuel (Suivre le colis / Voir le QR / Détails).
- `StatusChipsRow<T>` : chips scrollables, comparateur `equals` optionnel (pour les `Set`), `trailing` (bouton filtre période).
- Segmented glissant : capsule blanche `AnimatedAlign` suivant `controller.index` (swipe + tap), badges préservés.

### Appels API
- `GET /travelers/me/trips-summary` → `{activeTrips, kgSoldThisMonth, revenueThisMonth}`. 403 si non-voyageur. Cache backend 5 min. Côté front, erreur ⇒ bandeau masqué (dégradation silencieuse).

### Pièges et points d'attention
- Le bandeau stats est **masqué** (pas de skeleton persistant) tant que non `loaded` — volontaire.
- `TripCard` reçoit `key: ValueKey(announcement.id)` depuis la liste pour préserver l'identité (animations) lors des tris/refresh.
- `RefreshIndicator.onRefresh` attend que le bloc atteigne `AnnouncementListLoaded`/`AnnouncementError` avant de rendre la main (sinon le spinner disparaît avant les données).
- `HANDED_OVER` (REMIS) est traité comme un état **actif** (badge info), cohérent avec IN_TRANSIT — ce n'est pas un état terminal.
- Le calcul du mois courant (`23:59:59`) suit volontairement la convention du `TravelerStatsService` existant.

## Critères d'acceptation couverts
- ✅ Direction « Éditorial calme » + drapeaux sur la timeline.
- ✅ Bandeau mini-stats (endpoint dédié créé côté back, tout voyageur).
- ✅ Navigation par chips colorés (Airbnb) à la place des onglets.
- ✅ Accès expéditeur via pill header ; **partie Envoyer seule pour le rôle expéditeur unique** (logique `annoncesLayoutFor` inchangée).
- ✅ Hub Envoyer : segmented glissant + chips + stepper colis + état vide soigné.
- ✅ Onglet « Annonces » → « Activités ».
- ✅ Analytics `trip_filter_applied` (sans PII) ; table CLAUDE.md à jour.
- ✅ Tests : 3628 Flutter verts, suite backend verte, nouvelles classes couvertes ; `flutter analyze` 0 warning/erreur sur les fichiers touchés.

## Décisions techniques
- Endpoint `trips-summary` distinct de `/travelers/me/stats` : pas de gate Pro, payload minimal, réutilise les queries `PaymentRepository`/`AnnouncementRepository` existantes + une nouvelle somme kg.
- Filtrage 100 % local côté front (la liste est déjà chargée) — pas d'appel réseau par changement de chip.
- `TripsSummaryModel` non-Equatable → `TripsSummaryState.props` décompose ses 3 champs.
- `StatusChipsRow` générique avec comparateur `equals` pour supporter à la fois des enums (`==`) et des `Set<String>` (`setEquals`).
