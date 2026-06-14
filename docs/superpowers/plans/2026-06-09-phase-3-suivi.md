# Phase 3 — Suivi (additif + ScanHub réel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre l'onglet Suivi additif et in-shell (suivi colis = socle, scan = ajout voyageur, primaire selon `isProAccount`), et **câbler le ScanHub aux vraies données** (fin du placeholder `_TripStub`).

**Architecture :** Un dispatcher `SuiviScreen` compose par profil (via `AuthBloc`). Le ScanHub est piloté par un nouveau `ScanHubCubit` (repos `Announcement`+`Bid`), dont la logique (sélection du trajet à scanner + compteurs dérivés des statuts bids) est **pure et testée**. Les écrans `TrackingSearchScreen` et le flux `/tracking/scan*` sont réutilisés ; la file offline (NFR1) est intacte.

**Tech Stack :** Flutter, flutter_bloc, GoRouter, GetIt, flutter_test, bloc_test ^9, mocktail ^1.

**Réf spec :** `docs/superpowers/specs/2026-06-09-phase-3-suivi-design.md` · **Fondation :** `2026-06-08-navigation-additive-model-foundation.md`

**Données réelles disponibles (vérifiées) :**
- `AnnouncementRepository.getMyAnnouncements()` → `Future<({List<AnnouncementModel> announcements, int totalElements})>`.
- `BidRepository.getBidsForAnnouncement(String id)` → `Future<List<BidModel>>`.
- `AnnouncementModel` : `id`, `departureCity`, `arrivalCity`, `departureDate`, `status` (`ACTIVE`/`FULL`/`IN_PROGRESS`/`COMPLETED`/`CANCELLED`).
- `BidModel` : `id`, `announcementId`, `status` (`ACCEPTED`/`HANDED_OVER`/`IN_TRANSIT`/`COMPLETED`/…).
- DI : `AnnouncementRepository` & `BidRepository` = lazySingletons ; cubits enregistrés en `registerFactory(() => X(getIt<Repo>(), getIt<AnalyticsService>()))`.

**Garantie zéro-régression :**
- Pur expéditeur → suivi colis (désormais in-shell = amélioration).
- Voyageur → scan QR (étapes/photo/GPS), identification, **file offline** → préservés ; le ScanHub passe du placeholder au réel.
- `TrackingSearchScreen` + flux `/tracking/scan*` + offline sync : inchangés fonctionnellement.

**Stratégie de test (réaliste) :** TDD sur les fonctions pures (`suiviLayoutFor`, `selectScannableTrip`, `computeScanProgress`) + le `ScanHubCubit` (bloc_test + mocktail). Les écrans composés (dispatcher, ScanHub UI states, TrackingSearch in-shell) sont validés par checklist QA (Task 10).

⚠️ **Pré-requis backend à confirmer AVANT Task 2** : la correspondance statut bid ↔ étape (`HANDED_OVER` = scanné au départ ?). Si différente, ajuster `computeScanProgress` (et ses tests).

---

## File Structure

| Fichier | Rôle |
|---|---|
| `lib/features/tracking/presentation/suivi_layout.dart` | **Créé.** `SuiviLayout` + `suiviLayoutFor()` pur. |
| `lib/features/tracking/bloc/scan_hub_selectors.dart` | **Créé.** `selectScannableTrip()` + `computeScanProgress()` + `ScanHubProgress` (purs). |
| `lib/features/tracking/bloc/scan_hub_cubit.dart` | **Créé.** `ScanHubCubit` + `ScanHubState`. |
| `lib/features/tracking/presentation/screens/suivi_screen.dart` | **Créé.** Dispatcher Suivi (composition par profil). |
| `lib/features/tracking/presentation/screens/scan_hub_screen.dart` | **Modifié.** Suppression `_TripStub` ; hero + état vide via `ScanHubCubit` ; param `onTrackParcel`. |
| `lib/features/tracking/presentation/screens/tracking_search_screen.dart` | **Modifié.** Param `onScanTrip` ; back-button géré pour l'in-shell. |
| `lib/core/di/injection.dart` | **Modifié.** Enregistre `ScanHubCubit`. |
| `lib/app/router.dart` | **Modifié.** `/tracking` → `SuiviScreen` ; ajout `/tracking/scan-hub`. |
| `lib/app/main_shell.dart` | **Modifié.** Onglet Suivi : icône figée, toujours in-shell. |
| `lib/core/services/analytics_events.dart` + `CLAUDE.md` | **Modifié.** Events. |
| `test/features/tracking/presentation/suivi_layout_test.dart` | **Créé.** |
| `test/features/tracking/bloc/scan_hub_selectors_test.dart` | **Créé.** |
| `test/features/tracking/bloc/scan_hub_cubit_test.dart` | **Créé.** |

> `SecondaryActivityEntry` (créé en Phase 2) est réutilisé tel quel.

---

### Task 1 : Logique pure `suiviLayoutFor()`

**Files:** Create `lib/features/tracking/presentation/suivi_layout.dart` · Test `test/features/tracking/presentation/suivi_layout_test.dart`

- [ ] **Step 1 : Test qui échoue**

```dart
import 'package:dony/features/tracking/presentation/suivi_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non voyageur → senderOnly', () {
    expect(suiviLayoutFor(isTraveler: false, isPro: false), SuiviLayout.senderOnly);
    expect(suiviLayoutFor(isTraveler: false, isPro: true), SuiviLayout.senderOnly);
  });
  test('voyageur non pro → occasionalTraveler', () {
    expect(suiviLayoutFor(isTraveler: true, isPro: false), SuiviLayout.occasionalTraveler);
  });
  test('voyageur pro → proTraveler', () {
    expect(suiviLayoutFor(isTraveler: true, isPro: true), SuiviLayout.proTraveler);
  });
}
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `flutter test test/features/tracking/presentation/suivi_layout_test.dart` → FAIL (URI introuvable).

- [ ] **Step 3 : Implémenter**

```dart
// lib/features/tracking/presentation/suivi_layout.dart
enum SuiviLayout { senderOnly, occasionalTraveler, proTraveler }

SuiviLayout suiviLayoutFor({required bool isTraveler, required bool isPro}) {
  if (!isTraveler) return SuiviLayout.senderOnly;
  if (isPro) return SuiviLayout.proTraveler;
  return SuiviLayout.occasionalTraveler;
}
```

- [ ] **Step 4 : Vérifier le succès** → `flutter test test/features/tracking/presentation/suivi_layout_test.dart` → PASS.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/tracking/presentation/suivi_layout.dart test/features/tracking/presentation/suivi_layout_test.dart
git commit -m "feat(suivi): logique pure du layout par profil (SuiviLayout)"
```

---

### Task 2 : Sélecteurs purs du ScanHub (trajet + compteurs)

**Files:** Create `lib/features/tracking/bloc/scan_hub_selectors.dart` · Test `test/features/tracking/bloc/scan_hub_selectors_test.dart`

> ⚠️ Confirmer d'abord la sémantique des statuts bids (cf. en-tête). Les constantes ci-dessous encodent l'hypothèse validée en spec.

- [ ] **Step 1 : Test qui échoue**

```dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _trip(String id, String status, DateTime date) => AnnouncementModel(
  // NB: compléter les champs requis du constructeur réel (voir announcement_model.dart).
  id: id, status: status, departureDate: date,
  departureCity: 'Paris', arrivalCity: 'Dakar',
);
BidModel _bid(String status) => BidModel(
  id: 'b', announcementId: 'a', status: status, // compléter champs requis
);

void main() {
  group('selectScannableTrip', () {
    test('priorité au IN_PROGRESS le plus proche', () {
      final trips = [
        _trip('1', 'ACTIVE', DateTime(2026, 7, 1)),
        _trip('2', 'IN_PROGRESS', DateTime(2026, 6, 20)),
        _trip('3', 'IN_PROGRESS', DateTime(2026, 6, 10)),
      ];
      expect(selectScannableTrip(trips)?.id, '3');
    });
    test('sinon le prochain ACTIVE/FULL', () {
      final trips = [
        _trip('1', 'COMPLETED', DateTime(2026, 1, 1)),
        _trip('2', 'ACTIVE', DateTime(2026, 7, 5)),
        _trip('3', 'FULL', DateTime(2026, 6, 28)),
      ];
      expect(selectScannableTrip(trips)?.id, '3');
    });
    test('aucun trajet scannable → null', () {
      expect(selectScannableTrip([_trip('1', 'CANCELLED', DateTime(2026, 1, 1))]), isNull);
      expect(selectScannableTrip(const []), isNull);
    });
  });

  group('computeScanProgress', () {
    test('confirmés et scannés départ dérivés du statut', () {
      final bids = [
        _bid('ACCEPTED'), _bid('HANDED_OVER'), _bid('IN_TRANSIT'),
        _bid('COMPLETED'), _bid('REJECTED'), _bid('PENDING'),
      ];
      final p = computeScanProgress(bids);
      expect(p.confirmedColis, 4); // ACCEPTED+HANDED_OVER+IN_TRANSIT+COMPLETED
      expect(p.scannedDepart, 3);  // HANDED_OVER+IN_TRANSIT+COMPLETED
    });
  });
}
```

- [ ] **Step 2 : Vérifier l'échec** → FAIL (URI introuvable). Ajuster les constructeurs `_trip`/`_bid` aux champs requis réels de `announcement_model.dart` / `bid_model.dart`.

- [ ] **Step 3 : Implémenter**

```dart
// lib/features/tracking/bloc/scan_hub_selectors.dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

const _confirmedStatuses = {'ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED'};
const _departedStatuses = {'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED'};

class ScanHubProgress {
  const ScanHubProgress({required this.confirmedColis, required this.scannedDepart});
  final int confirmedColis;
  final int scannedDepart;
}

/// Trajet à scanner : IN_PROGRESS le plus proche, sinon prochain ACTIVE/FULL, sinon null.
AnnouncementModel? selectScannableTrip(List<AnnouncementModel> trips) {
  int byDate(AnnouncementModel a, AnnouncementModel b) =>
      a.departureDate.compareTo(b.departureDate);

  final inProgress = trips.where((t) => t.status == 'IN_PROGRESS').toList()..sort(byDate);
  if (inProgress.isNotEmpty) return inProgress.first;

  final upcoming = trips
      .where((t) => t.status == 'ACTIVE' || t.status == 'FULL')
      .toList()
    ..sort(byDate);
  return upcoming.isNotEmpty ? upcoming.first : null;
}

ScanHubProgress computeScanProgress(List<BidModel> bids) {
  return ScanHubProgress(
    confirmedColis: bids.where((b) => _confirmedStatuses.contains(b.status)).length,
    scannedDepart: bids.where((b) => _departedStatuses.contains(b.status)).length,
  );
}
```

- [ ] **Step 4 : Vérifier le succès** → `flutter test test/features/tracking/bloc/scan_hub_selectors_test.dart` → PASS.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/tracking/bloc/scan_hub_selectors.dart test/features/tracking/bloc/scan_hub_selectors_test.dart
git commit -m "feat(suivi): sélecteurs purs ScanHub (trajet à scanner + compteurs)"
```

---

### Task 3 : `ScanHubCubit` + état + DI

**Files:** Create `lib/features/tracking/bloc/scan_hub_cubit.dart` · Modify `lib/core/di/injection.dart` · Test `test/features/tracking/bloc/scan_hub_cubit_test.dart`

- [ ] **Step 1 : Test qui échoue (bloc_test + mocktail)**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}
class _MockBidRepo extends Mock implements BidRepository {}
class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockAnnouncementRepo annRepo;
  late _MockBidRepo bidRepo;
  late _MockAnalytics analytics;

  setUp(() {
    annRepo = _MockAnnouncementRepo();
    bidRepo = _MockBidRepo();
    analytics = _MockAnalytics();
  });

  AnnouncementModel trip(String id, String status) => AnnouncementModel(
    id: id, status: status, departureDate: DateTime(2026, 6, 10),
    departureCity: 'Paris', arrivalCity: 'Dakar', // compléter champs requis
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'aucun trajet → ScanHubEmpty',
    build: () {
      when(() => annRepo.getMyAnnouncements())
          .thenAnswer((_) async => (announcements: <AnnouncementModel>[], totalElements: 0));
      return ScanHubCubit(annRepo, bidRepo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubEmpty>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'trajet IN_PROGRESS → ScanHubLoaded',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (announcements: [trip('a', 'IN_PROGRESS')], totalElements: 1));
      when(() => bidRepo.getBidsForAnnouncement('a')).thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubLoaded>()],
  );
}
```

- [ ] **Step 2 : Vérifier l'échec** → FAIL (URI introuvable).

- [ ] **Step 3 : Implémenter le cubit**

```dart
// lib/features/tracking/bloc/scan_hub_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';

sealed class ScanHubState {
  const ScanHubState();
}
class ScanHubLoading extends ScanHubState { const ScanHubLoading(); }
class ScanHubEmpty extends ScanHubState { const ScanHubEmpty(); }
class ScanHubError extends ScanHubState {
  const ScanHubError(this.message);
  final String message;
}
class ScanHubLoaded extends ScanHubState {
  const ScanHubLoaded({required this.trip, required this.progress});
  final AnnouncementModel trip;
  final ScanHubProgress progress;
}

class ScanHubCubit extends Cubit<ScanHubState> {
  ScanHubCubit(this._announcementRepo, this._bidRepo, this._analytics)
      : super(const ScanHubLoading());

  final AnnouncementRepository _announcementRepo;
  final BidRepository _bidRepo;
  // ignore: unused_field — injecté par convention projet (events futurs)
  final AnalyticsService _analytics;

  Future<void> load() async {
    emit(const ScanHubLoading());
    try {
      final result = await _announcementRepo.getMyAnnouncements();
      final trip = selectScannableTrip(result.announcements);
      if (trip == null) {
        emit(const ScanHubEmpty());
        return;
      }
      final bids = await _bidRepo.getBidsForAnnouncement(trip.id);
      emit(ScanHubLoaded(trip: trip, progress: computeScanProgress(bids)));
    } catch (e) {
      emit(ScanHubError(e.toString()));
    }
  }
}
```

- [ ] **Step 4 : Enregistrer dans la DI**

Dans `lib/core/di/injection.dart`, près des autres factories tracking (ex. `TrackingBloc` l.501) :

```dart
  getIt.registerFactory(
    () => ScanHubCubit(
      getIt<AnnouncementRepository>(),
      getIt<BidRepository>(),
      getIt<AnalyticsService>(),
    ),
  );
```

Ajouter l'import `import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';` si besoin.

- [ ] **Step 5 : Vérifier le succès** → `flutter test test/features/tracking/bloc/scan_hub_cubit_test.dart` → PASS.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/tracking/bloc/scan_hub_cubit.dart lib/core/di/injection.dart test/features/tracking/bloc/scan_hub_cubit_test.dart
git commit -m "feat(suivi): ScanHubCubit (trajet réel + compteurs) + DI"
```

---

### Task 4 : ScanHub réel — suppression de `_TripStub`, hero + état vide

**Files:** Modify `lib/features/tracking/presentation/screens/scan_hub_screen.dart`

- [ ] **Step 1 : Paramétrer `_TripHeroCard`**

Remplacer la classe `_TripHeroCard` (l.67) pour qu'elle prenne ses données en paramètres au lieu de `_TripStub` :

```dart
class _TripHeroCard extends StatelessWidget {
  const _TripHeroCard({
    required this.corridor,
    required this.dateLabel,
    required this.confirmedColis,
    required this.scannedDepart,
  });

  final String corridor;
  final String dateLabel;
  final int confirmedColis;
  final int scannedDepart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = confirmedColis == 0 ? 0.0 : scannedDepart / confirmedColis;
    // … même UI, en remplaçant _TripStub.corridor → corridor,
    //   _TripStub.date → dateLabel, _TripStub.totalColis → confirmedColis,
    //   _TripStub.scannedDepart → scannedDepart …
  }
}
```

- [ ] **Step 2 : Piloter le body par `ScanHubCubit` + ajouter le param `onTrackParcel`**

Convertir `ScanHubScreen` pour fournir le cubit et basculer selon l'état. Remplacer la classe (l.27) :

```dart
class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({super.key, this.onTrackParcel});

  /// Entrée additive « Suivre un colis » (voyageur pro). Null = non affichée.
  final VoidCallback? onTrackParcel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ScanHubCubit>()..load(),
      child: _ScanHubView(onTrackParcel: onTrackParcel),
    );
  }
}
```

Créer `_ScanHubView` (le Scaffold + AppBar « Scan & Suivi » existants), avec un `BlocBuilder<ScanHubCubit, ScanHubState>` :

```dart
        body: BlocBuilder<ScanHubCubit, ScanHubState>(
          builder: (context, state) {
            switch (state) {
              case ScanHubLoading():
                return Center(child: CircularProgressIndicator(color: cs.primary));
              case ScanHubError(:final message):
                return _ErrorState(message: message,
                    onRetry: () => context.read<ScanHubCubit>().load());
              case ScanHubEmpty():
                return const _NoTripState(); // mascotte + "Voir mes trajets" → context.push('/announcements/trips')
              case ScanHubLoaded(:final trip, :final progress):
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onTrackParcel != null) ...[
                        SecondaryActivityEntry(
                          icon: Icons.local_shipping_rounded,
                          label: 'Suivre un colis',
                          onTap: onTrackParcel!,
                        ),
                        const SizedBox(height: DonySpacing.lg),
                      ],
                      _TripHeroCard(
                        corridor: '${trip.departureCity} → ${trip.arrivalCity}',
                        dateLabel: _formatDate(trip.departureDate),
                        confirmedColis: progress.confirmedColis,
                        scannedDepart: progress.scannedDepart,
                      ),
                      const SizedBox(height: DonySpacing.xl),
                      _EtapesSection(),
                      const SizedBox(height: DonySpacing.xl),
                      _QuickActionsSection(),
                    ],
                  ),
                );
            }
          },
        ),
```

Supprimer la classe `_TripStub` (l.5-10). Implémenter `_NoTripState` (réutiliser `DonyEmptyState` avec CTA « Voir mes trajets » → `context.push('/announcements/trips')`), `_ErrorState`, et un helper `_formatDate` (via `intl`/`DateFormat`). Ajouter imports : `scan_hub_cubit.dart`, `secondary_activity_entry.dart`, `injection.dart`, `flutter_bloc`, `go_router`, `design_system` (déjà là).

- [ ] **Step 3 : Vérifier compilation + analyze**

Run: `flutter analyze lib/features/tracking/presentation/screens/scan_hub_screen.dart`
Expected: aucune erreur ; plus aucune référence à `_TripStub`.

- [ ] **Step 4 : Commit**

```bash
git add lib/features/tracking/presentation/screens/scan_hub_screen.dart
git commit -m "feat(suivi): ScanHub câblé aux vraies données (fin de _TripStub) + état vide + entrée pro"
```

---

### Task 5 : Entrée « Scanner un trajet » sur `TrackingSearchScreen` + in-shell

**Files:** Modify `lib/features/tracking/presentation/screens/tracking_search_screen.dart`

- [ ] **Step 1 : Inspecter l'écran**

Run: `grep -n "class TrackingSearchScreen\|AppBar\|showBackButton\|DonyAppBar\|leading\|const TrackingSearchScreen" lib/features/tracking/presentation/screens/tracking_search_screen.dart`
Repérer la déclaration de classe et l'AppBar (présence d'un bouton retour).

- [ ] **Step 2 : Ajouter les params optionnels**

Ajouter au widget : `final VoidCallback? onScanTrip;` (entrée « Scanner un trajet ») et `final bool showBackButton;` (défaut `true` ; mis à `false` quand rendu in-shell). Threader `showBackButton` à l'AppBar (masquer le `leading`/back quand `false`).

- [ ] **Step 3 : Rendre l'entrée**

En haut du body (avant le champ de recherche), quand `onScanTrip != null` :

```dart
if (onScanTrip != null)
  Padding(
    padding: const EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.sm, DonySpacing.lg, 0),
    child: SecondaryActivityEntry(
      icon: Icons.qr_code_scanner_rounded,
      label: 'Scanner un trajet',
      onTap: onScanTrip!,
    ),
  ),
```

Ajouter l'import `secondary_activity_entry.dart`.

- [ ] **Step 4 : Vérifier compilation** → `flutter analyze lib/features/tracking/presentation/screens/tracking_search_screen.dart` → aucune erreur (params optionnels → usage en route `/tracking/search` inchangé).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/tracking/presentation/screens/tracking_search_screen.dart
git commit -m "feat(suivi): entrée 'Scanner un trajet' + mode in-shell sur TrackingSearchScreen"
```

---

### Task 6 : Dispatcher `SuiviScreen` (composition par profil)

**Files:** Create `lib/features/tracking/presentation/screens/suivi_screen.dart`

- [ ] **Step 1 : Implémenter le dispatcher**

```dart
// lib/features/tracking/presentation/screens/suivi_screen.dart
import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_search_screen.dart';
import 'package:dony/features/tracking/presentation/suivi_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Onglet Suivi — additif, in-shell, piloté par le profil (voir spec Phase 3).
class SuiviScreen extends StatelessWidget {
  const SuiviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final UserModel? user = switch (authState) {
      AuthAuthenticated s => s.user,
      AuthProfileUpdated s => s.user,
      _ => null,
    };
    final layout = suiviLayoutFor(
      isTraveler: user?.isTraveler ?? false,
      isPro: user?.isProAccount ?? false,
    );

    switch (layout) {
      case SuiviLayout.senderOnly:
        return const TrackingSearchScreen(showBackButton: false);

      case SuiviLayout.occasionalTraveler:
        return TrackingSearchScreen(
          showBackButton: false,
          onScanTrip: () {
            unawaited(getIt<AnalyticsService>()
                .logEvent(AnalyticsEvents.suiviScanOpened));
            context.push('/tracking/scan-hub');
          },
        );

      case SuiviLayout.proTraveler:
        return ScanHubScreen(
          onTrackParcel: () {
            unawaited(getIt<AnalyticsService>()
                .logEvent(AnalyticsEvents.suiviTrackOpened));
            context.push('/tracking/search');
          },
        );
    }
  }
}
```

- [ ] **Step 2 : Vérifier compilation** → `flutter analyze lib/features/tracking/presentation/screens/suivi_screen.dart`
Expected : erreurs uniquement sur `AnalyticsEvents.suiviScanOpened/suiviTrackOpened` (ajoutés Task 9) — faire Task 9 avant, ou ignorer jusque-là.

- [ ] **Step 3 : Commit**

```bash
git add lib/features/tracking/presentation/screens/suivi_screen.dart
git commit -m "feat(suivi): dispatcher SuiviScreen (composition par profil)"
```

---

### Task 7 : Routes — `/tracking` → SuiviScreen, ajout `/tracking/scan-hub`

**Files:** Modify `lib/app/router.dart`

- [ ] **Step 1 : Rebrancher la branche `/tracking`**

À la branche `StatefulShellBranch` du tracking (l.935-943), remplacer le builder (l.939) :

```dart
              builder: (context, state) => const ScanHubScreen(),
```

par :

```dart
              builder: (context, state) => const SuiviScreen(),
```

Ajouter l'import `import 'package:dony/features/tracking/presentation/screens/suivi_screen.dart';`.

- [ ] **Step 2 : Ajouter la route poussée du ScanHub (pour l'entrée occasionnel)**

À côté des routes `/tracking/*` (ex. après `/tracking/search` l.596-602) :

```dart
GoRoute(
  path: '/tracking/scan-hub',
  builder: (context, state) => const ScanHubScreen(),
),
```

(`ScanHubScreen` fournit déjà son `ScanHubCubit` en interne — Task 4 Step 2.)

- [ ] **Step 3 : Vérifier `/tracking/search`**

Laisser la route `/tracking/search` (l.596) telle quelle — elle reste la destination poussée de l'entrée « Suivre un colis » du pro et du deep-link. (L'instance poussée garde son `showBackButton` par défaut `true`.)

- [ ] **Step 4 : Vérifier compilation** → `flutter analyze lib/app/router.dart` → aucune erreur.

- [ ] **Step 5 : Commit**

```bash
git add lib/app/router.dart
git commit -m "feat(suivi): /tracking → SuiviScreen + route /tracking/scan-hub"
```

---

### Task 8 : Bottom-nav — onglet Suivi figé & in-shell

**Files:** Modify `lib/app/main_shell.dart`

- [ ] **Step 1 : Figer l'icône et supprimer le push hors-shell**

Remplacer la dérivation d'icône (l.178-181) :

```dart
        // Tab 2 — Suivi (libellé fixe, icône role-aware)
        final tab2Icon = isTraveler
            ? Icons.qr_code_scanner_rounded
            : Icons.track_changes_rounded;
```

par :

```dart
        // Tab 2 — Suivi (libellé + icône figés ; contenu adapté au profil
        // dans SuiviScreen — voir spec Phase 3)
        const tab2Icon = Icons.local_shipping_rounded;
```

Puis le `onTap` du tab Suivi (l.227-234), remplacer tout le bloc par un simple in-shell :

```dart
                  onTap: () => onTap(2),
```

- [ ] **Step 2 : Vérifier compilation** → `flutter analyze lib/app/main_shell.dart`
Expected : aucune erreur. (`isTraveler` reste utilisé tant que la `BlocBuilder<ActiveRoleCubit>` est là ; si après Phases 1+2+3 `isTraveler` n'est plus utilisé du tout dans ce widget, retirer la `BlocBuilder<ActiveRoleCubit>` résiduelle et lire `isProAccount`/autres via AuthBloc — sinon laisser, suppression finale en Phase 4.)

- [ ] **Step 3 : Commit**

```bash
git add lib/app/main_shell.dart
git commit -m "feat(suivi): onglet Suivi figé + toujours in-shell (fin du push hors-shell)"
```

---

### Task 9 : Analytics — events des entrées Suivi

**Files:** Modify `lib/core/services/analytics_events.dart` + `CLAUDE.md`

- [ ] **Step 1 : Déclarer les events**

Dans `analytics_events.dart`, section Suivi (près des events Tracking, l.31-33) :

```dart
  // Suivi (entrées additives)
  static const suiviScanOpened  = 'suivi_scan_opened';
  static const suiviTrackOpened = 'suivi_track_opened';
```

- [ ] **Step 2 : Table d'events `CLAUDE.md`**

Ajouter :

```
| `suivi_scan_opened`  | SuiviScreen — entrée « Scanner un trajet » (voyageur occasionnel) |
| `suivi_track_opened` | SuiviScreen — entrée « Suivre un colis » (voyageur pro) |
```

- [ ] **Step 3 : Vérifier compilation globale** → `flutter analyze` → aucune erreur (le dispatcher Task 6 résout ses constantes).

- [ ] **Step 4 : Commit**

```bash
git add lib/core/services/analytics_events.dart CLAUDE.md
git commit -m "feat(suivi): analytics des entrées additives (scan/track opened)"
```

---

### Task 10 : Vérification finale (format, analyze, suite, QA)

- [ ] **Step 1 : Format + analyze**

Run: `dart format lib/features/tracking/ lib/app/ test/features/tracking/ && flutter analyze`
Expected : « No issues found ».

- [ ] **Step 2 : Suite + couverture** → `flutter test --coverage`
Expected : tous PASS (suites tracking/offline existantes incluses).

- [ ] **Step 3 : Checklist QA manuelle**

- [ ] **Pur expéditeur** : onglet Suivi = recherche colis, **in-shell** (pas de plein écran hors-shell), aucune entrée scan.
- [ ] **Voyageur occasionnel** : recherche colis + entrée « 📷 Scanner un trajet » → ouvre le ScanHub.
- [ ] **Voyageur pro** : ScanHub **réel** (vrai trajet en cours, vrais compteurs) + entrée « 📦 Suivre un colis » → ouvre la recherche.
- [ ] **ScanHub sans trajet** : **état vide réel** (« Aucun trajet à scanner… Voir mes trajets »), plus de « Paris → Dakar » bidon.
- [ ] **Scan** : flux QR/numéro/photo/GPS fonctionne ; **scan hors-ligne** → mis en file et synchronisé à la reconnexion (NFR1).
- [ ] **Bottom-nav** : onglet « Suivi » icône identique quel que soit le profil ; toujours in-shell.
- [ ] **PostHog** : `suivi_scan_opened` / `suivi_track_opened` émis aux taps.

- [ ] **Step 4 : Commit final**

```bash
git add -A
git commit -m "chore(suivi): vérification finale Phase 3 (additif + ScanHub réel)"
```

---

## Self-review (effectuée)

- **Couverture spec :** composition par profil (T1, T6) · in-shell + nav figée (T7, T8) · entrées secondaires (T5, T6, réutilise `SecondaryActivityEntry`) · **ScanHub réel** (T2, T3, T4) · état vide (T4) · offline préservé (non touché) · analytics (T9) · zéro-régression (QA T10). ✅
- **Pas de placeholder :** seuls steps « inspecter » (T5 grep) concrets.
- **Cohérence des types :** `SuiviLayout`, `suiviLayoutFor`, `selectScannableTrip`, `computeScanProgress`/`ScanHubProgress{confirmedColis,scannedDepart}`, `ScanHubCubit`/`ScanHubState`(`Loading/Empty/Error/Loaded{trip,progress}`), `ScanHubScreen.onTrackParcel`, `TrackingSearchScreen.onScanTrip`/`showBackButton`, routes `/tracking`, `/tracking/scan-hub`, `/tracking/search`, events `suiviScanOpened`/`suiviTrackOpened` — cohérents.
- **Dépendances inter-tâches :** faire Task 9 (events) avant Task 6 si on veut éviter l'erreur transitoire. Les constructeurs de test (T2/T3) doivent être complétés avec les champs requis réels de `AnnouncementModel`/`BidModel`.
- **Note honnête :** logique pure + cubit testés (TDD) ; écrans composés validés en QA (T10). ⚠️ Confirmer la sémantique statut-bid↔étape avant T2.
