# Colis sur mes trajets — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Créer l'écran `/package-requests/match` qui pré-filtre les demandes d'envoi compatibles avec les trajets actifs du voyageur et permet de faire une offre avec la date pré-remplie.

**Architecture:** `ColisMatchScreen` (nouveau) utilise `AnnouncementBloc` (existant) pour lister les trajets actifs et `PackageRequestSearchBloc` (existant) pour chercher les colis compatibles. Un seul paramètre est ajouté à `MakeOfferBottomSheet.show()` (`initialDate`). La route `profile_screen.dart` bascule de `/package-requests/search` vers `/package-requests/match`.

**Tech Stack:** Flutter · flutter_bloc · GoRouter · flutter_animate · intl · mocktail · bloc_test

---

## Fichiers

| Action | Fichier |
|--------|---------|
| Modifier | `lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart` |
| Modifier | `lib/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart` |
| Créer | `lib/features/package_request/presentation/screens/traveler/colis_match_screen.dart` |
| Modifier | `lib/app/router.dart` |
| Modifier | `lib/features/profile/presentation/profile_screen.dart` |
| Créer | `test/features/package_request/presentation/widgets/make_offer_bottom_sheet_test.dart` |
| Créer | `test/features/package_request/presentation/screens/traveler/colis_match_screen_test.dart` |

---

### Task 1 : `MakeOfferBottomSheet` — paramètre `initialDate`

**Fichiers :**
- Modifier : `lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart`
- Créer : `test/features/package_request/presentation/widgets/make_offer_bottom_sheet_test.dart`

- [ ] **Étape 1 : Écrire les tests qui échouent**

Créer `test/features/package_request/presentation/widgets/make_offer_bottom_sheet_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockPriceEstimationRepository extends Mock
    implements PriceEstimationRepository {}

void main() {
  late _MockNegotiationBloc negoBloc;
  late _MockPriceEstimationRepository priceRepo;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
  });

  setUp(() {
    negoBloc = _MockNegotiationBloc();
    priceRepo = _MockPriceEstimationRepository();

    when(() => negoBloc.state).thenReturn(const NegotiationInitial());
    when(() => negoBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
    when(() => priceRepo.estimate(
          from: any(named: 'from'),
          to: any(named: 'to'),
          weight: any(named: 'weight'),
        )).thenThrow(Exception('no estimate'));

    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<PriceEstimationRepository>()) {
      getIt.unregister<PriceEstimationRepository>();
    }
    getIt.registerFactory<NegotiationBloc>(() => negoBloc);
    getIt.registerLazySingleton<PriceEstimationRepository>(() => priceRepo);
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<PriceEstimationRepository>()) {
      getIt.unregister<PriceEstimationRepository>();
    }
  });

  Widget wrap({DateTime? initialDate}) => MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (ctx, state) => Builder(
                builder: (innerCtx) => ElevatedButton(
                  onPressed: () => MakeOfferBottomSheet.show(
                    innerCtx,
                    packageRequestId: 'pr-1',
                    weightKg: 5,
                    departureCity: 'Paris',
                    arrivalCity: 'Dakar',
                    initialDate: initialDate,
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
            GoRoute(
              path: '/negotiations/:id',
              builder: (_, __) =>
                  const Scaffold(body: Text('Négociation')),
            ),
          ],
        ),
        theme: AppTheme.light,
      );

  group('MakeOfferBottomSheet', () {
    testWidgets(
        'initialDate fourni → champ date affiche la valeur formatée',
        (tester) async {
      await tester.pumpWidget(wrap(initialDate: DateTime(2026, 6, 12)));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // DateFormat('EEE d MMM yyyy', 'fr').format(DateTime(2026, 6, 12))
      // produit "ven. 12 juin 2026" en fr
      expect(find.textContaining('12 juin 2026'), findsOneWidget);
      expect(find.text('Sélectionner…'), findsNothing);
    });

    testWidgets(
        'sans initialDate → champ date affiche Sélectionner',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Sélectionner…'), findsOneWidget);
    });
  });
}
```

- [ ] **Étape 2 : Vérifier que les tests échouent**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/package_request/presentation/widgets/make_offer_bottom_sheet_test.dart
```

Résultat attendu : FAIL — `MakeOfferBottomSheet.show()` n'a pas de paramètre `initialDate`.

- [ ] **Étape 3 : Ajouter `initialDate` à `MakeOfferBottomSheet`**

Dans `lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart` :

**Signature de `show()`** — ajouter `DateTime? initialDate` avant `}) async` :

```dart
static Future<void> show(
  BuildContext context, {
  required String packageRequestId,
  double? targetPriceEur,
  required double weightKg,
  required String departureCity,
  required String arrivalCity,
  DateTime? initialDate,          // ← nouveau
}) async {
```

**Constructeur `_MakeOfferContent`** — ajouter le champ et le transmettre :

```dart
class _MakeOfferContent extends StatefulWidget {
  const _MakeOfferContent({
    required this.packageRequestId,
    required this.targetPriceEur,
    required this.weightKg,
    required this.estimate,
    required this.rootRouter,
    required this.onSubmitReady,
    this.initialDate,              // ← nouveau
  });

  final String packageRequestId;
  final double? targetPriceEur;
  final double weightKg;
  final PriceEstimate? estimate;
  final GoRouter rootRouter;
  final void Function(VoidCallback) onSubmitReady;
  final DateTime? initialDate;    // ← nouveau
```

**Dans `show()`, passer `initialDate` au widget :**

```dart
child: _MakeOfferContent(
  packageRequestId: packageRequestId,
  targetPriceEur: targetPriceEur,
  weightKg: weightKg,
  estimate: estimate,
  rootRouter: rootRouter,
  onSubmitReady: (fn) => submitFn = fn,
  initialDate: initialDate,        // ← nouveau
),
```

**Dans `_MakeOfferContentState.initState()`** — initialiser le notifier si la date est fournie :

```dart
@override
void initState() {
  super.initState();
  widget.onSubmitReady(_submit);
  _priceCtrl = TextEditingController(
    text: widget.targetPriceEur != null
        ? widget.targetPriceEur!.toStringAsFixed(0)
        : '',
  );
  _kgCtrl = TextEditingController(text: widget.weightKg.toStringAsFixed(1));
  _bodyCtrl = TextEditingController();
  if (widget.initialDate != null) _dateNotifier.value = widget.initialDate; // ← nouveau
}
```

- [ ] **Étape 4 : Vérifier que les tests passent**

```bash
flutter test test/features/package_request/presentation/widgets/make_offer_bottom_sheet_test.dart
```

Résultat attendu : 2/2 PASS.

- [ ] **Étape 5 : Commit**

```bash
git add lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart \
        test/features/package_request/presentation/widgets/make_offer_bottom_sheet_test.dart
git commit -m "feat(package-request): ajouter initialDate à MakeOfferBottomSheet"
```

---

### Task 2 : `PackageRequestPublicDetailScreen` — pré-remplissage depuis GoRouter extras

**Fichiers :**
- Modifier : `lib/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart`

- [ ] **Étape 1 : Ajouter les imports manquants**

En haut du fichier, après les imports existants :

```dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:go_router/go_router.dart';
```

- [ ] **Étape 2 : Lire les extras GoRouter dans `build()` et les passer à `_buildBody`**

Remplacer la méthode `build()` par :

```dart
@override
Widget build(BuildContext context) {
  final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
  final announcement = extra?['announcement'] as AnnouncementModel?;
  final cs = Theme.of(context).colorScheme;
  return Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: const DonyAppBar(title: 'Demande'),
    body: _loading
        ? Center(child: CircularProgressIndicator(color: cs.primary))
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(fontSize: 14, color: kError)),
                ),
              )
            : _request == null
                ? const SizedBox.shrink()
                : _buildBody(_request!, announcement),
  );
}
```

- [ ] **Étape 3 : Mettre à jour la signature de `_buildBody` et l'appel à `MakeOfferBottomSheet`**

Changer la signature :

```dart
Widget _buildBody(PackageRequest r, AnnouncementModel? announcement) {
```

Dans `_buildBody`, remplacer l'appel à `MakeOfferBottomSheet.show` :

```dart
onPressed: () => MakeOfferBottomSheet.show(
  context,
  packageRequestId: r.id,
  targetPriceEur: r.targetPriceEur,
  weightKg: announcement?.availableKg ?? r.weightKg,
  departureCity: r.departureCity,
  arrivalCity: r.arrivalCity,
  initialDate: announcement?.departureDate,
),
```

- [ ] **Étape 4 : Vérifier qu'aucun test existant n'est cassé**

```bash
flutter test test/features/package_request/
```

Résultat attendu : tous les tests existants passent.

- [ ] **Étape 5 : Commit**

```bash
git add lib/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart
git commit -m "feat(package-request): pré-remplir date et kg depuis extras GoRouter dans detail screen"
```

---

### Task 3 : Créer `ColisMatchScreen`

**Fichiers :**
- Créer : `lib/features/package_request/presentation/screens/traveler/colis_match_screen.dart`
- Créer : `test/features/package_request/presentation/screens/traveler/colis_match_screen_test.dart`

- [ ] **Étape 1 : Écrire les tests qui échouent**

Créer `test/features/package_request/presentation/screens/traveler/colis_match_screen_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/colis_match_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockPackageRequestSearchBloc
    extends MockBloc<PackageRequestSearchEvent, PackageRequestSearchState>
    implements PackageRequestSearchBloc {}

AnnouncementModel _ann({
  String id = 'ann-1',
  String departure = 'Paris',
  String arrival = 'Dakar',
  String status = 'ACTIVE',
  double availableKg = 15,
  double totalKg = 23,
}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'u-1',
      departureCity: departure,
      arrivalCity: arrival,
      departureDate: DateTime(2026, 6, 12),
      availableKg: availableKg,
      totalKg: totalKg,
      pricePerKg: 5,
      status: status,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

PackageRequestSearchItem _searchItem({String id = 'pr-1'}) =>
    PackageRequestSearchItem(
      id: id,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 10),
      dateToleranceDays: 2,
      weightKg: 3,
      parcelSize: ParcelSize.small,
      contentCategory: ContentCategory.vetements,
    );

void main() {
  late _MockAnnouncementBloc announcementBloc;
  late _MockPackageRequestSearchBloc searchBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(const AnnouncementListRequested());
    registerFallbackValue(const SearchFiltersChanged());
  });

  setUp(() {
    announcementBloc = _MockAnnouncementBloc();
    searchBloc = _MockPackageRequestSearchBloc();

    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    when(() => searchBloc.state)
        .thenReturn(const PackageRequestSearchState());
    when(() => searchBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestSearchState>.empty());

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<PackageRequestSearchBloc>()) {
      getIt.unregister<PackageRequestSearchBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    getIt.registerFactory<PackageRequestSearchBloc>(() => searchBloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<PackageRequestSearchBloc>()) {
      getIt.unregister<PackageRequestSearchBloc>();
    }
  });

  Widget wrap() => MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(
              path: '/', builder: (_, __) => const ColisMatchScreen()),
          GoRoute(
              path: '/announcements/create',
              builder: (_, __) =>
                  const Scaffold(body: Text('Créer trajet'))),
          GoRoute(
              path: '/package-requests/:id/public',
              builder: (_, __) =>
                  const Scaffold(body: Text('Détail colis'))),
        ]),
        theme: AppTheme.light,
      );

  group('ColisMatchScreen', () {
    testWidgets('chips générés depuis annonces ACTIVE et FULL seulement',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementListLoaded([
        _ann(id: 'a1', departure: 'Paris', arrival: 'Dakar', status: 'ACTIVE'),
        _ann(id: 'a2', departure: 'Lyon', arrival: 'Abidjan', status: 'FULL'),
        _ann(
            id: 'a3',
            departure: 'Nice',
            arrival: 'Bamako',
            status: 'CLOSED'),
      ]));

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Paris→Dakar'), findsOneWidget);
      expect(find.textContaining('Lyon→Abidjan'), findsOneWidget);
      expect(find.textContaining('Nice→Bamako'), findsNothing);
    });

    testWidgets(
        'sélection chip → SearchFiltersChanged avec bons departure/arrival',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementListLoaded([
        _ann(id: 'a1', departure: 'Paris', arrival: 'Dakar', status: 'ACTIVE'),
        _ann(
            id: 'a2',
            departure: 'Lyon',
            arrival: 'Abidjan',
            status: 'ACTIVE'),
      ]));

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.textContaining('Lyon→Abidjan'));
      await tester.pump();

      verify(() => searchBloc.add(any(
            that: isA<SearchFiltersChanged>()
                .having((e) => e.departure, 'departure', 'Lyon')
                .having((e) => e.arrival, 'arrival', 'Abidjan'),
          ))).called(greaterThanOrEqualTo(1));
    });

    testWidgets(
        'état vide "Aucun trajet actif" quand AnnouncementListLoaded([])',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementListLoaded([]));

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Aucun trajet actif'), findsOneWidget);
      expect(find.text('Publier un trajet'), findsOneWidget);
    });

    testWidgets(
        'état vide "Aucun colis ne correspond" quand search loaded vide',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementListLoaded([_ann()]));
      when(() => searchBloc.state).thenReturn(const PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [],
      ));

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Aucun colis ne correspond'), findsOneWidget);
    });

    testWidgets('tap carte → navigation vers /package-requests/:id/public',
        (tester) async {
      when(() => announcementBloc.state)
          .thenReturn(AnnouncementListLoaded([_ann()]));
      when(() => searchBloc.state).thenReturn(PackageRequestSearchState(
        status: SearchStatus.loaded,
        results: [_searchItem()],
      ));

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(PackageRequestListCard));
      await tester.pumpAndSettle();

      expect(find.text('Détail colis'), findsOneWidget);
    });

    testWidgets('CapacityBanner affiche availableKg et totalKg de l\'annonce',
        (tester) async {
      when(() => announcementBloc.state).thenReturn(AnnouncementListLoaded([
        _ann(availableKg: 15.0, totalKg: 23.0),
      ]));

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('15.0 kg restants'), findsOneWidget);
      expect(find.textContaining('23.0 kg total'), findsOneWidget);
    });
  });
}
```

- [ ] **Étape 2 : Vérifier que les tests échouent**

```bash
flutter test test/features/package_request/presentation/screens/traveler/colis_match_screen_test.dart
```

Résultat attendu : FAIL — `ColisMatchScreen` n'existe pas.

- [ ] **Étape 3 : Créer `ColisMatchScreen`**

Créer `lib/features/package_request/presentation/screens/traveler/colis_match_screen.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/package_request_search_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ColisMatchScreen extends StatelessWidget {
  const ColisMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<AnnouncementBloc>()
            ..add(const AnnouncementListRequested()),
        ),
        BlocProvider(
          create: (_) => getIt<PackageRequestSearchBloc>(),
        ),
      ],
      child: const _ColisMatchView(),
    );
  }
}

class _ColisMatchView extends StatefulWidget {
  const _ColisMatchView();

  @override
  State<_ColisMatchView> createState() => _ColisMatchViewState();
}

class _ColisMatchViewState extends State<_ColisMatchView> {
  final _selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _search(BuildContext ctx, AnnouncementModel ann) {
    ctx.read<PackageRequestSearchBloc>().add(SearchFiltersChanged(
          departure: ann.departureCity,
          arrival: ann.arrivalCity,
          dateFrom: ann.departureDate.subtract(const Duration(days: 7)),
          dateTo: ann.departureDate.add(const Duration(days: 7)),
        ));
  }

  void _selectChip(
      BuildContext ctx, List<AnnouncementModel> active, int index) {
    _selectedIndexNotifier.value = index;
    _search(ctx, active[index]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: BlocBuilder<PackageRequestSearchBloc,
            PackageRequestSearchState>(
          builder: (_, state) {
            final count = state.results.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Colis sur mes trajets',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                if (count > 0)
                  Text(
                    '$count compatible${count > 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
              ],
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outline),
        ),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (ctx, state) {
          if (state is AnnouncementListLoaded) {
            final active = state.announcements
                .where(
                    (a) => a.status == 'ACTIVE' || a.status == 'FULL')
                .toList();
            if (active.isEmpty) return;
            final idx = _selectedIndexNotifier.value
                .clamp(0, active.length - 1);
            _selectedIndexNotifier.value = idx;
            _search(ctx, active[idx]);
          }
        },
        builder: (ctx, state) {
          if (state is AnnouncementInitial || state is AnnouncementLoading) {
            return Center(
                child: CircularProgressIndicator(color: cs.primary));
          }
          if (state is AnnouncementError) {
            return _ErrorView(
              onRetry: () => ctx
                  .read<AnnouncementBloc>()
                  .add(const AnnouncementListRequested()),
            );
          }
          if (state is AnnouncementListLoaded) {
            final active = state.announcements
                .where(
                    (a) => a.status == 'ACTIVE' || a.status == 'FULL')
                .toList();

            if (active.isEmpty) {
              return const _NoTripsEmptyView();
            }

            return ValueListenableBuilder<int>(
              valueListenable: _selectedIndexNotifier,
              builder: (_, selectedIdx, __) {
                final ann = active[selectedIdx];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChipsBar(
                      announcements: active,
                      selectedIndex: selectedIdx,
                      onTap: (i) => _selectChip(ctx, active, i),
                    ),
                    _CapacityBanner(announcement: ann),
                    Expanded(child: _ResultsView(announcement: ann)),
                  ],
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── Chips bar ──────────────────────────────────────────────────────────────

class _ChipsBar extends StatelessWidget {
  const _ChipsBar({
    required this.announcements,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<AnnouncementModel> announcements;
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: List.generate(announcements.length, (i) {
            final ann = announcements[i];
            final isActive = i == selectedIndex;
            final label =
                '✈ ${ann.departureCity}→${ann.arrivalCity} · ${DateFormat('d MMM', 'fr').format(ann.departureDate)}';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Capacity banner ─────────────────────────────────────────────────────────

class _CapacityBanner extends StatelessWidget {
  const _CapacityBanner({required this.announcement});
  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.scale_rounded, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text.rich(TextSpan(children: [
            TextSpan(
              text:
                  '${announcement.availableKg.toStringAsFixed(1)} kg restants',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  fontSize: 12),
            ),
            TextSpan(
              text:
                  ' · ${announcement.totalKg.toStringAsFixed(1)} kg total',
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ])),
        ],
      ),
    );
  }
}

// ─── Results list ────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.announcement});
  final AnnouncementModel announcement;

  void _triggerSearch(
      BuildContext ctx, AnnouncementModel ann) {
    ctx.read<PackageRequestSearchBloc>().add(SearchFiltersChanged(
          departure: ann.departureCity,
          arrival: ann.arrivalCity,
          dateFrom: ann.departureDate.subtract(const Duration(days: 7)),
          dateTo: ann.departureDate.add(const Duration(days: 7)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestSearchBloc,
        PackageRequestSearchState>(
      builder: (ctx, state) {
        if (state.status == SearchStatus.loading ||
            state.status == SearchStatus.initial) {
          return Center(
            child: CircularProgressIndicator(
                color: Theme.of(ctx).colorScheme.primary),
          );
        }

        if (state.status == SearchStatus.error) {
          return _ErrorView(
            onRetry: () => _triggerSearch(ctx, announcement),
          );
        }

        if (state.results.isEmpty &&
            state.status == SearchStatus.loaded) {
          return const _NoResultsEmptyView();
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification &&
                n.metrics.extentAfter < 200 &&
                state.hasMore &&
                state.status == SearchStatus.loaded) {
              ctx
                  .read<PackageRequestSearchBloc>()
                  .add(const SearchLoadMore());
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async =>
                _triggerSearch(ctx, announcement),
            child: ListView.separated(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 40),
              itemCount: state.results.length +
                  (state.status == SearchStatus.loadingMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
              itemBuilder: (lCtx, i) {
                if (i == state.results.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color:
                              Theme.of(lCtx).colorScheme.primary),
                    ),
                  );
                }
                final item = state.results[i];
                return PackageRequestListCard(
                  item: item,
                  index: i,
                  onTap: () => lCtx.push(
                    '/package-requests/${item.id}/public',
                    extra: {'announcement': announcement},
                  ),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 60 * i),
                      duration: 280.ms,
                    )
                    .slideY(
                        begin: 0.04,
                        curve: Curves.easeOutCubic);
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _NoTripsEmptyView extends StatelessWidget {
  const _NoTripsEmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_rounded,
                size: 64,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Aucun trajet actif',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Publie un trajet pour voir les colis compatibles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            DonyButton(
              label: 'Publier un trajet',
              onPressed: () => context.push('/announcements/create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsEmptyView extends StatelessWidget {
  const _NoResultsEmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_rounded,
                size: 64,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Aucun colis ne correspond à ce trajet pour l\'instant.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text('Une erreur est survenue',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 24),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Étape 4 : Vérifier que les tests passent**

```bash
flutter test test/features/package_request/presentation/screens/traveler/colis_match_screen_test.dart
```

Résultat attendu : 6/6 PASS.

- [ ] **Étape 5 : Commit**

```bash
git add lib/features/package_request/presentation/screens/traveler/colis_match_screen.dart \
        test/features/package_request/presentation/screens/traveler/colis_match_screen_test.dart
git commit -m "feat(package-request): créer ColisMatchScreen avec chips, capacity banner et liste paginée"
```

---

### Task 4 : Router + profile_screen

**Fichiers :**
- Modifier : `lib/app/router.dart`
- Modifier : `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Étape 1 : Ajouter l'import de `ColisMatchScreen` dans `router.dart`**

En haut du fichier `lib/app/router.dart`, avec les autres imports de package_request :

```dart
import 'package:dony/features/package_request/presentation/screens/traveler/colis_match_screen.dart';
```

- [ ] **Étape 2 : Ajouter la route `/package-requests/match` dans `router.dart`**

Dans `lib/app/router.dart`, avant la route `/package-requests/search` (ligne ~559) :

```dart
GoRoute(
  path: '/package-requests/match',
  builder: (_, __) => const ColisMatchScreen(),
),
```

- [ ] **Étape 3 : Mettre à jour `profile_screen.dart`**

Dans `lib/features/profile/presentation/profile_screen.dart`, ligne ~305 :

```dart
// Avant
onTap: () => context.push('/package-requests/search'),
// Après
onTap: () => context.push('/package-requests/match'),
```

- [ ] **Étape 4 : Vérifier que tous les tests passent**

```bash
flutter test
```

Résultat attendu : tous les tests passent (y compris les tests de profil existants).

- [ ] **Étape 5 : Commit**

```bash
git add lib/app/router.dart \
        lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(router): ajouter route /package-requests/match et mettre à jour profile_screen"
```

---

## Auto-vérification du plan

### Couverture du spec

| Exigence spec | Tâche qui la couvre |
|---------------|---------------------|
| `ColisMatchScreen` avec chips ACTIVE/FULL | Task 3 |
| `CapacityBanner` availableKg/totalKg | Task 3 |
| Recherche ±7j autour de departureDate | Task 3 (`_search()`) |
| Chip actif → fond primary / inactif → surfaceVariant | Task 3 (`_ChipsBar`) |
| État vide aucun trajet → CTA `/announcements/create` | Task 3 |
| État vide aucun résultat → message neutre | Task 3 |
| Tap carte → push avec extra `announcement` | Task 3 |
| `MakeOfferBottomSheet.show()` → `initialDate` optionnel | Task 1 |
| `PackageRequestPublicDetailScreen` → lecture extras | Task 2 |
| Route `/package-requests/match` | Task 4 |
| `profile_screen.dart` → lien mis à jour | Task 4 |
| Animation fadeIn + slideY sur la liste | Task 3 (`_ResultsView`) |
| Tests make_offer_bottom_sheet | Task 1 |
| Tests colis_match_screen (6 tests) | Task 3 |

### Cohérence des types

- `AnnouncementModel.availableKg: double`, `AnnouncementModel.totalKg: double` → `toStringAsFixed(1)` ✓
- `AnnouncementModel.departureDate: DateTime` → `.subtract(Duration(days: 7))` ✓
- `SearchFiltersChanged.departure: String?` → `ann.departureCity` ✓
- `_selectedIndexNotifier.value.clamp(0, active.length - 1)` → type `int` ✓
- `PackageRequestListCard(item: PackageRequestSearchItem, index: int, onTap: VoidCallback?)` ✓

### Rétrocompatibilité

- `MakeOfferBottomSheet.show()` : `initialDate` est optionnel — tous les appels existants compilent sans modification ✓
- `_buildBody(PackageRequest r, AnnouncementModel? announcement)` : `announcement` nullable — comportement identique quand `null` ✓
