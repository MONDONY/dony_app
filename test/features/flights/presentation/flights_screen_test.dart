import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/bloc/flight_deals_cubit.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/bloc/flight_places_cubit.dart';
import 'package:dony/features/flights/bloc/flight_search_cubit.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_defaults.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:dony/features/flights/presentation/flights_screen.dart';
import 'package:dony/features/flights/presentation/widgets/flight_billet_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_deal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../bloc/flights_test_doubles.dart';

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

class _Probe implements FirebaseSessionProbe {
  const _Probe();
  @override
  bool get hasSession => true;
  @override
  bool get isAnonymous => false;
  @override
  bool get hasRealSession => true;
}

void _register<T extends Object>(T Function() factory) {
  if (getIt.isRegistered<T>()) getIt.unregister<T>();
  getIt.registerFactory<T>(factory);
}

void main() {
  late MockFlightsRepository repository;

  setUpAll(() => registerFallbackValue(const FlightSearchQuery()));

  setUp(() {
    repository = MockFlightsRepository();
    final analytics = silentAnalytics();
    when(() => repository.defaults()).thenAnswer(
      (_) async => const FlightDefaults(
        source: 'search',
        origin: FlightPlace(code: 'PAR', name: 'Paris'),
        destination: FlightPlace(code: 'ABJ', name: 'Abidjan'),
      ),
    );
    when(() => repository.deals()).thenAnswer(
      (_) async => FlightDeals(
        currency: 'EUR',
        personalized: true,
        deals: [
          FlightDeal(
            offer: offer('deal', departureAt: DateTime(2026, 12, 14)),
            medianPrice: 600,
            discountPercent: 28,
          ),
        ],
      ),
    );
    when(() => repository.search(any())).thenAnswer(
      (_) async => FlightSearchResult(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        roundTrip: false,
        currency: 'EUR',
        offers: [
          offer('a'),
          offer('b', price: 489, transfers: 0, minutes: 380),
        ],
      ),
    );
    _register<FlightSearchCubit>(
      () => FlightSearchCubit(repository, analytics),
    );
    _register<FlightDealsCubit>(() => FlightDealsCubit(repository));
    _register<FlightLinkCubit>(
      () => FlightLinkCubit(repository, analytics, _MockLauncher()),
    );
    _register<FlightPlacesCubit>(
      () => FlightPlacesCubit(repository, debounce: Duration.zero),
    );
    _register<FlightAlertsCubit>(
      () => FlightAlertsCubit(repository, analytics),
    );
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      getIt.unregister<FirebaseSessionProbe>();
    }
    getIt.registerSingleton<FirebaseSessionProbe>(const _Probe());
  });

  tearDown(() {
    for (final unregister in [
      getIt.unregister<FlightSearchCubit>,
      getIt.unregister<FlightDealsCubit>,
      getIt.unregister<FlightLinkCubit>,
      getIt.unregister<FlightPlacesCubit>,
      getIt.unregister<FlightAlertsCubit>,
      getIt.unregister<FirebaseSessionProbe>,
    ]) {
      unregister();
    }
  });

  testWidgets('formulaire prérempli et bons plans, puis résultats en billets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localizedApp(const FlightsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Billets'), findsOneWidget);
    expect(find.text('Paris (PAR)'), findsOneWidget);
    expect(find.text('Abidjan (ABJ)'), findsOneWidget);
    expect(find.byType(FlightDealCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(FlightBilletCard), findsWidgets);
    expect(find.text('Le moins cher'), findsOneWidget);
    expect(find.text('Le plus rapide'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('flights-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Trier par'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feuilles ville et dates : choix d\'une ville et d\'un mois', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localizedApp(const FlightsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flights-destination')));
    await tester.pumpAndSettle();
    expect(find.text("Ville d'arrivée"), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-city-DKR')));
    await tester.pumpAndSettle();
    expect(find.text('Dakar (DKR)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flights-departure-date')));
    await tester.pumpAndSettle();
    expect(find.text('Quand partez-vous ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-dates-month')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    await tester.tap(find.byKey(Key('flight-month-${now.year}-${now.month}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-dates-validate')));
    await tester.pumpAndSettle();
    expect(find.text('Quand partez-vous ?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('créer une alerte depuis les résultats ouvre la feuille', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localizedApp(const FlightsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flights-create-alert')));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle alerte'), findsOneWidget);
    expect(find.byKey(const Key('flight-alert-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
