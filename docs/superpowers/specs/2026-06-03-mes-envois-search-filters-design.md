# Design — Onglet « Envoyer » : 3 onglets + recherche/filtres

**Date :** 2026-06-03
**Fichiers cibles :**
- `lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart` (dashboard → 3 onglets)
- `lib/features/matching/presentation/screens/shipment_list_screen.dart` (Envois : recherche + statut + période)
- `lib/features/matching/bloc/shipment_filter_cubit.dart` (**nouveau**)
- `lib/features/matching/presentation/widgets/shipment_status_filter_sheet.dart` (**nouveau**)
- `lib/features/matching/presentation/widgets/shipment_period_filter_sheet.dart` (**nouveau**)
- `lib/features/package_request/bloc/request_filter_cubit.dart` (**nouveau** — recherche Demandes)
- `lib/features/package_request/bloc/negotiation_filter_cubit.dart` (**nouveau** — recherche Négos)
- `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart` (+ recherche)
- `lib/features/package_request/presentation/screens/shared/my_negotiations_screen.dart` (+ recherche)

**Status :** En revue

---

## Contexte

L'onglet « Envoyer » de l'expéditeur (`EnvoyerHubScreen`) est aujourd'hui un **tableau de bord à 3 cartes** (Demandes / Envois / Négociations) ; chaque carte ouvre une section plein écran via un `_activeSection` en `setState`. Problèmes signalés : **pas intuitif** (indirection dashboard → section) et **impossible de rechercher/filtrer ses envois**.

**Objectif :**
1. Remplacer le dashboard par **3 onglets directs** : `Envois · Demandes · Négos` (accès en 1 tap, plus clair).
2. **Envois** : recherche large + filtre **statut** précis (multi) avec presets + filtre **période** (toggle date départ/création).
3. **Demandes** & **Négos** : **ajouter une recherche** ; conserver leurs presets de statut actuels (pas de période, pas de statut multi).

**Décisions validées avec l'utilisateur :**
- Structure **B** : 3 onglets en haut (remplace le dashboard).
- Envois = recherche (ville départ/arrivée + destinataire + voyageur + n° suivi) + statut précis + période (sélecteur **date de départ / date de création**).
- Demandes & Négos = **recherche seulement** (+ presets existants conservés).
- On conserve les puces rapides Envois `Tous / En cours / À venir / Passés`.

**Contraintes projet :** aucun `setState` (état porté par Cubits ou `DefaultTabController`), aucun appel réseau ajouté (filtrage 100 % client sur les données déjà chargées), `DonyButton` des bottom sheets en `stickyBottom`, analytics sans PII, couverture ≥ 90 %.

---

## 1. Structure — `EnvoyerHubScreen` : dashboard → 3 onglets

**Suppressions :** `_activeSection` + `_buildDashboard`/`_buildSectionView`, `_DashboardHeader`, `_DashboardScrollBody`, `_DemandesCard`/`_EnvoisCard`/`_NegosCard`, `_ActivityHubCard`, `_CountPill`, `_RequestPreviewItem`/`_BidPreviewItem`/`_NegoPreviewItem`, `_buildActivityDots`, `_SectionHeader`. (Gros allègement.)

**Conservé :** le `MultiBlocProvider` (`PackageRequestBloc`, `BidBloc`, `NegotiationListBloc`) + le bouton **+ Nouveau** (flux KYC → `PackageRequestCreateWizard`).

**Nouveau layout :** `DefaultTabController(length: 3)` (gère l'onglet actif **sans `setState`**) :

```
SafeArea
 └ Column
    ├ header : « Envoyer »  ………………………  [ + Nouveau ]
    ├ _EnvoyerSegmented (TabBar custom)  →  Envois N · Demandes N · Négos N
    └ Expanded( TabBarView[ ShipmentListBody, MyPackageRequestsBody, MyNegotiationsBody ] )
```

- `_EnvoyerSegmented` : `TabBar` stylé en segment (réutilise le visuel pills vert actif), libellés avec compteurs issus des 3 blocs via `BlocBuilder` (Envois = bids actifs, Demandes = requests actives, Négos = `activeCount`).
- Les 3 bodies sont déjà des widgets autonomes (`ShipmentListBody`, `MyPackageRequestsBody`, `MyNegotiationsBody`) → on les place dans le `TabBarView`.
- **Analytics** : sur changement d'onglet, `logScreen('envoyer_envois' | 'envoyer_demandes' | 'envoyer_negos')` (états visuels distincts — cf. règle CLAUDE.md), via un listener sur le `TabController`.

---

## 2. Onglet Envois — recherche + statut + période

### 2.1 Source de vérité unique : `statuses: Set<String>`

Les puces rapides ET le sheet « Statut » écrivent dans le **même** `Set<String>`.
- Puce rapide = raccourci remplaçant `statuses` par un groupe connu (ou `{}` = « Tous »).
- Sheet « Statut » = édition libre, statut par statut.
- Puce rapide « active » = **dérivée** (groupe == `statuses` ; `{}` ⇒ « Tous »).

Groupes (repris de `_populateLists`) :

| Preset | Statuts |
|--------|---------|
| **En cours** | `ACCEPTED`, `HANDED_OVER`, `IN_TRANSIT` |
| **À venir** | `PENDING`, `AWAITING_PAYMENT`, `PAYMENT_ESCROWED` |
| **Passés** | `COMPLETED`, `REJECTED`, `CANCELLED`, `NO_SHOW`, `EXPIRED`, `PARCEL_REFUSED` |
| **Tous** | `{}` |

Libellés FR (repris de `_ShipmentCard._statusLabel`) : `PENDING`→En attente · `AWAITING_PAYMENT`→À payer · `PAYMENT_ESCROWED`→Payé · `ACCEPTED`→Confirmé · `HANDED_OVER`→En route · `IN_TRANSIT`→En transit · `COMPLETED`→Livré · `REJECTED`/`PARCEL_REFUSED`→Refusé · `CANCELLED`→Annulé · `NO_SHOW`→Absent · `EXPIRED`→Expiré.
Groupes d'affichage du sheet : **En cours** / **En attente** / **Terminés** (Livré) / **Clôturés**.

### 2.2 `ShipmentFilterCubit` (nouveau)

`lib/features/matching/bloc/shipment_filter_cubit.dart`

```dart
enum ShipmentPeriodBasis { departure, creation }
enum ShipmentPeriodPreset { all, thisWeek, thisMonth, last3Months, thisYear, custom }

class ShipmentFilterState extends Equatable {
  final String query;
  final Set<String> statuses;             // {} = tous
  final ShipmentPeriodBasis periodBasis;  // défaut departure
  final ShipmentPeriodPreset periodPreset;// défaut all
  final DateTimeRange? customRange;
  const ShipmentFilterState({this.query = '', this.statuses = const {},
      this.periodBasis = ShipmentPeriodBasis.departure,
      this.periodPreset = ShipmentPeriodPreset.all, this.customRange});
  bool get hasActiveFilters =>
      query.trim().isNotEmpty || statuses.isNotEmpty || periodPreset != ShipmentPeriodPreset.all;
  ShipmentFilterState copyWith({...});
  @override List<Object?> get props => [query, statuses, periodBasis, periodPreset, customRange];
}

class ShipmentFilterCubit extends Cubit<ShipmentFilterState> {
  ShipmentFilterCubit(this._analytics) : super(const ShipmentFilterState());
  final AnalyticsService _analytics;
  void setQuery(String q) => emit(state.copyWith(query: q));          // pas d'analytics ici
  void setStatuses(Set<String> s) { emit(state.copyWith(statuses: s)); _track(); }
  void applyQuickPreset(Set<String> group) { emit(state.copyWith(statuses: group)); _track(); }
  void setPeriod({required ShipmentPeriodBasis basis, required ShipmentPeriodPreset preset, DateTimeRange? range}) {emit(...); _track();}
  void reset() => emit(const ShipmentFilterState());
  void _track() => unawaited(_analytics.logEvent(AnalyticsEvents.shipmentFilterApplied, properties: {
        'has_query': state.query.trim().isNotEmpty,   // jamais le texte (PII)
        'status_count': state.statuses.length,
        'period_preset': state.periodPreset.name,
        'period_basis': state.periodBasis.name,
      }));
}
```

### 2.3 Fonctions pures (testables sans widget)

**Réutilise** `normalizeSearch` de `bid_list_filter_cubit.dart` (minuscule + diacritiques) — l'importer, ne pas dupliquer.

```dart
bool shipmentMatchesQuery(BidModel b, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  bool m(String? s) => s != null && normalizeSearch(s).contains(q);
  return m(b.departureCity) || m(b.arrivalCity) || m(b.recipientName) ||
         m(b.travelerName) || m(b.trackingNumber);
}
DateTime shipmentDateFor(BidModel b, ShipmentPeriodBasis basis) =>
    basis == ShipmentPeriodBasis.departure ? (b.departureDate ?? b.createdAt) : b.createdAt;
DateTimeRange? rangeForPreset(ShipmentPeriodPreset p, DateTimeRange? custom, DateTime now); // null = all
List<BidModel> applyShipmentFilters(List<BidModel> bids, ShipmentFilterState f, DateTime now) {
  Iterable<BidModel> out = bids;
  if (f.statuses.isNotEmpty) out = out.where((b) => f.statuses.contains(b.status));
  if (f.query.trim().isNotEmpty) out = out.where((b) => shipmentMatchesQuery(b, f.query));
  final r = rangeForPreset(f.periodPreset, f.customRange, now);
  if (r != null) out = out.where((b) { final d = shipmentDateFor(b, f.periodBasis);
      return !d.isBefore(r.start) && !d.isAfter(r.end); });
  return _sortBids(out.toList());   // tri existant conservé (priorité statut puis date)
}
```

`rangeForPreset` (bornes inclusives, basé sur `now` injecté) : `all`→null · `thisWeek`→lundi 00:00→now · `thisMonth`→1er du mois→now · `last3Months`→now−90j→now · `thisYear`→1er janv→now · `custom`→`customRange` (fin à 23:59:59).

### 2.4 Refonte `shipment_list_screen.dart`

**Suppressions :** `enum _Tab`, `_tab/_inProgress/_upcoming/_past`, `_populateLists`, `_buildTabBody`, `_EmbeddedTabBar`/`_EmbeddedTab`, et les 3 onglets de `_DarkHeader`.

**Ajouts :** `BlocProvider(create: (_) => getIt<ShipmentFilterCubit>())` + `_ShipmentFilterBar` (embedded & standalone) :

```
🔍 Ville, destinataire, voyageur…           (DonySearchField, debounce 250 ms → cubit.setQuery)
[Statut ▾] [Période ▾]                       (ouvrent les 2 sheets)
Tous · En cours · À venir · Passés           (puces rapides, scroll horizontal)
[Livré ✕] [Ce mois ✕] · Réinitialiser        (si hasActiveFilters)
3 résultats                                  (= liste filtrée)
```

- Liste = `BlocBuilder<ShipmentFilterCubit>` + `BlocBuilder<BidBloc>` → `applyShipmentFilters(bids, f, DateTime.now())` → `_ShipmentListView` (réutilisé : `_ShipmentCard`, pull-to-refresh, paiement, dismiss-to-delete sur clôturés/livrés).
- Recherche débouncée ~250 ms (timer dans le State, annulé à `dispose`).

---

## 3. Onglet Demandes — + recherche

`RequestFilterCubit` (`request_filter_cubit.dart`) : `state { query, RequestQuickFilter preset }` avec `preset ∈ {all, open, accepted}` (reprend l'`_StatusFilter` actuel). Refactor `_ListContent` (suppr. `setState _filter`) → `BlocBuilder<RequestFilterCubit>`.

```dart
bool requestMatchesQuery(PackageRequest r, String q) {  // réutilise normalizeSearch
  final n = normalizeSearch(q.trim()); if (n.isEmpty) return true;
  bool m(String? s) => s != null && normalizeSearch(s).contains(n);
  return m(r.departureCity) || m(r.arrivalCity) || m(r.contentCategory.label);
}
```

UI : ajouter `DonySearchField` (« Ville, catégorie… ») au-dessus du `_FilterRow` existant (presets conservés). Filtrage = preset ∩ recherche. État vide filtré conservé (`_FilterEmptyState`) ; ajouter le cas « aucun résultat pour la recherche ».

---

## 4. Onglet Négos — + recherche

`NegotiationFilterCubit` (`negotiation_filter_cubit.dart`) : `state { query, NegoQuickFilter preset }` avec `preset ∈ {all, active, terminal}` (reprend l'`_StatusFilter` actuel). Refactor `_MyNegotiationsBodyState` (suppr. `setState _filter`) → `BlocBuilder`.

```dart
bool negoMatchesQuery(NegotiationThread t, String q) {  // réutilise normalizeSearch
  final n = normalizeSearch(q.trim()); if (n.isEmpty) return true;
  bool m(String? s) => s != null && normalizeSearch(s).contains(n);
  return m(t.travelerName) || m(t.departureCity) || m(t.arrivalCity);
}
```

UI : `DonySearchField` (« Voyageur, ville… ») au-dessus des chips presets existantes. Filtrage = preset ∩ recherche.

---

## 5. Bottom sheets Envois (règle dony : boutons en `stickyBottom`)

- **`ShipmentStatusFilterSheet`** : groupes (En cours / En attente / Terminés / Clôturés) en multi-sélection (`DonyCheckbox`), `ValueNotifier<Set<String>>` initialisé à l'état courant, libellé « Appliquer (n) » via `ValueListenableBuilder` dans `stickyBottom`. Retour `Set<String>` → `cubit.setStatuses`.
- **`ShipmentPeriodFilterSheet`** : toggle **Date de départ / Date de création** + presets (Cette semaine · Ce mois-ci · 3 derniers mois · Cette année · Tout · **Personnalisé** → `showDateRangePicker` thémé `kGreenPrimary`), `stickyBottom: DonyButton('Appliquer')`. Retour `(basis, preset, range?)` → `cubit.setPeriod`.

Disposer les `ValueNotifier` via `.whenComplete(notifier.dispose)`.

---

## 6. États & bords

- **Vide global** (`items.isEmpty`) : états vides existants conservés (Envois `_EmptyView` + CTA ; Demandes `DonyEmptyState` ; Négos `DonyEmptyState`).
- **Vide filtré** (items non vides, résultat vide) : message « Aucun résultat » + bouton **Réinitialiser** (Envois : `cubit.reset()` ; Demandes/Négos : remet preset=all + query=''). Distinct du vide global.
- **Loading / Error** : inchangés ; barre de filtres masquée tant que pas de données.
- L'état de filtre survit au refresh et au changement d'onglet (porté par les Cubits).

---

## 7. Analytics

- Nouvel event `shipment_filter_applied` → `static const shipmentFilterApplied = 'shipment_filter_applied';` dans `AnalyticsEvents` ; tiré dans `ShipmentFilterCubit._track()` (jamais le texte). Mettre à jour la table d'events dans `dony_app/CLAUDE.md`.
- `logScreen` par onglet (`envoyer_envois`/`envoyer_demandes`/`envoyer_negos`) sur changement d'onglet (états distincts).
- Recherche Demandes/Négos : **pas** d'event (haute fréquence + PII possible).

---

## 8. DI (`lib/core/di/injection.dart`)

```dart
getIt.registerFactory(() => ShipmentFilterCubit(getIt<AnalyticsService>()));
getIt.registerFactory(() => RequestFilterCubit());
getIt.registerFactory(() => NegotiationFilterCubit());
```
(Les deux derniers sans analytics — pas d'event tiré.)

---

## 9. Fichiers

| Fichier | Action |
|---------|--------|
| `matching/bloc/shipment_filter_cubit.dart` | **Créer** (state + cubit + fonctions pures) |
| `matching/presentation/widgets/shipment_status_filter_sheet.dart` | **Créer** |
| `matching/presentation/widgets/shipment_period_filter_sheet.dart` | **Créer** |
| `matching/presentation/screens/shipment_list_screen.dart` | **Modifier** (filtre + suppr. onglets/setState) |
| `package_request/bloc/request_filter_cubit.dart` | **Créer** |
| `package_request/bloc/negotiation_filter_cubit.dart` | **Créer** |
| `package_request/presentation/screens/sender/my_package_requests_screen.dart` | **Modifier** (+ recherche, suppr. setState) |
| `package_request/presentation/screens/shared/my_negotiations_screen.dart` | **Modifier** (+ recherche, suppr. setState) |
| `package_request/presentation/screens/sender/envoyer_hub_screen.dart` | **Modifier** (dashboard → 3 onglets) |
| `core/di/injection.dart` | Enregistrer les 3 cubits |
| `core/services/analytics_events.dart` | Ajouter `shipmentFilterApplied` |
| `dony_app/CLAUDE.md` | Ajouter la ligne event |

**Ne pas toucher :** `bid_model.dart`, `bid_bloc.dart`/events/states, `package_request.dart`, `negotiation_thread.dart`, repositories/datasources, `router.dart`.

---

## 10. Tests (≥ 90 %)

**Cubits / fonctions pures**
- `shipment_filter_cubit_test.dart` : `shipmentMatchesQuery` (chaque champ, accents/casse, vide⇒tout) ; `rangeForPreset` (chaque preset, custom, all⇒null) ; `shipmentDateFor` (departure+fallback, creation) ; `applyShipmentFilters` (statut/recherche/période/combinaison ET/tri préservé) ; cubit (`setQuery` sans analytics ; `setStatuses/applyQuickPreset/setPeriod` ⇒ event sans texte ; `reset`).
- `request_filter_cubit_test.dart` : `requestMatchesQuery` ; preset∩recherche ; reset.
- `negotiation_filter_cubit_test.dart` : `negoMatchesQuery` ; preset∩recherche ; reset.

**Widget**
- `shipment_list_screen_test.dart` : recherche (debounce) ⇒ liste filtrée ; puce rapide ⇒ statuts du groupe ; sheet statut multi ⇒ `setStatuses` + libellé « Appliquer (n) » ; sheet période preset+toggle ⇒ `setPeriod`, custom ⇒ picker ; chips actifs (affichage, « ✕ », Réinitialiser) ; compteur ; vide filtré ≠ vide global.
- `my_package_requests_screen_test.dart` : recherche filtre la liste ; preset∩recherche ; vide filtré.
- `my_negotiations_screen_test.dart` : recherche filtre la liste ; preset∩recherche ; vide filtré.
- `envoyer_hub_screen_test.dart` : 3 onglets rendus ; bascule d'onglet affiche le bon body ; compteurs ; bouton + Nouveau (gate KYC) présent.

`flutter analyze` 0 erreur · `flutter test --coverage` ≥ 90 %.

---

## 11. Commits atomiques

```
feat(envois): ShipmentFilterCubit + fonctions pures (statut/recherche/période)
feat(envois): sheets Statut (multi) et Période (basis+presets+custom)
feat(envois): refonte liste Envois filter-first (suppr. onglets+setState)
feat(envoyer): hub 3 onglets (Envois/Demandes/Négos) — remplace le dashboard
feat(demandes): recherche + RequestFilterCubit (suppr. setState)
feat(negos): recherche + NegotiationFilterCubit (suppr. setState)
feat(envoyer): analytics shipment_filter_applied + logScreen par onglet
test(envoyer): cubits + fonctions pures + widget tests ≥ 90 %
```

---

## 12. Hors scope

- Période sur Demandes & Négos (décidé : recherche seulement).
- Statut multi précis sur Demandes & Négos (presets conservés).
- Tri configurable (tri existant conservé partout).
- L'onglet « Acceptées » côté voyageur (`BidListFilterCubit`) — inchangé.
- Découverte des trajets voyageurs (carte `/home`) — non concernée.
- État `setState` du loader bouton « Payer » dans `_ShipmentListView` (hérité paiement) : conservé tel quel (hors périmètre).
