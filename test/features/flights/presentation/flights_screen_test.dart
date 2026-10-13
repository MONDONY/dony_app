import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/bloc/flight_deals_cubit.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/bloc/flight_places_cubit.dart';
import 'package:dony/features/flights/bloc/flight_route_picker_cubit.dart';
import 'package:dony/features/flights/bloc/flight_search_cubit.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_defaults.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:dony/features/flights/presentation/flight_city_picker_screen.dart';
import 'package:dony/features/flights/presentation/flights_screen.dart';
import 'package:dony/features/flights/presentation/widgets/flight_deal_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_offer_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

const _paris = FlightPlace(code: 'PAR', name: 'Paris');
const _abidjan = FlightPlace(code: 'ABJ', name: 'Abidjan');
const _lille = FlightPlace(code: 'LIL', name: 'Lille');

Widget _app({Locale locale = AppL10n.fr, ThemeData? theme}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const FlightsScreen()),
      GoRoute(
        path: '/flights/city',
        builder: (_, state) =>
            FlightCityPickerScreen(args: state.extra! as FlightRoutePickerArgs),
      ),
      GoRoute(
        path: '/flights/alerts',
        builder: (_, _) => const Scaffold(body: Text('alertes')),
      ),
    ],
  );
  return MaterialApp.router(
    locale: locale,
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

FlightOffer _rich(
  String path,
  double price, {
  required int transfers,
  required int minutes,
}) => FlightOffer.fromJson({
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'departureAt': '2026-12-12T11:45:00+01:00',
  'arrivalAt': '2026-12-12T16:45:00Z',
  'price': price,
  'currency': 'EUR',
  'airlineCode': 'SS',
  'airlineName': 'Corsair',
  'transfers': transfers,
  'durationMinutes': minutes,
  'gate': 'Kiwi.com',
  'offerPath': path,
});

void main() {
  late MockFlightsRepository repository;
  late MemoryFlightRecentStore recents;
  late FlightDefaults defaults;
  late Future<FlightSearchResult> Function(FlightSearchQuery) search;

  setUpAll(() {
    registerFallbackValue(const FlightSearchQuery());
    registerFallbackValue(offer('fallback'));
  });

  setUp(() {
    repository = MockFlightsRepository();
    recents = MemoryFlightRecentStore();
    final analytics = silentAnalytics();
    defaults = const FlightDefaults(
      source: 'search',
      origin: _paris,
      destination: _abidjan,
    );
    search = (_) async => FlightSearchResult(
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      offers: [
        _rich('a', 431, transfers: 1, minutes: 585),
        _rich('b', 489, transfers: 0, minutes: 380),
        _rich('c', 520, transfers: 1, minutes: 700),
        _rich('d', 610, transfers: 2, minutes: 900),
      ],
      searchPath: '/search/PAR1212ABJ1',
    );
    when(() => repository.defaults()).thenAnswer((_) async => defaults);
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
      (inv) => search(inv.positionalArguments.first as FlightSearchQuery),
    );
    when(() => repository.places(any())).thenAnswer((_) async => const []);
    _register<FlightSearchCubit>(
      () => FlightSearchCubit(repository, analytics, recents: recents),
    );
    _register<FlightDealsCubit>(() => FlightDealsCubit(repository));
    _register<FlightLinkCubit>(
      () => FlightLinkCubit(repository, analytics, _MockLauncher()),
    );
    _register<FlightPlacesCubit>(
      () => FlightPlacesCubit(
        repository,
        debounce: Duration.zero,
        recents: recents,
      ),
    );
    if (getIt.isRegistered<FlightRoutePickerCubit>()) {
      getIt.unregister<FlightRoutePickerCubit>();
    }
    getIt.registerFactoryParam<
      FlightRoutePickerCubit,
      FlightRoutePickerArgs,
      void
    >((args, _) => FlightRoutePickerCubit(args));
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
      getIt.unregister<FlightRoutePickerCubit>,
      getIt.unregister<FlightAlertsCubit>,
      getIt.unregister<FirebaseSessionProbe>,
    ]) {
      unregister();
    }
  });

  Future<void> open(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(locale: locale, theme: theme));
    await tester.pumpAndSettle();
  }

  Finder rich(String text) => find.text(text, findRichText: true);

  /// Style de barre d'état exposé en haut de l'écran, celui que Flutter
  /// envoie au système à chaque image.
  SystemUiOverlayStyle? statusBar(WidgetTester tester) {
    final view = tester.view;
    final layer = tester.binding.renderViews.first.debugLayer!;
    return layer.find<SystemUiOverlayStyle>(
      Offset(view.physicalSize.width / 2, 1),
    );
  }

  group('barre d\'état', () {
    testWidgets('icônes sombres sur le formulaire et les résultats, claires '
        'pendant l\'attente et sur le choix de ville', (tester) async {
      final pending = Completer<FlightSearchResult>();
      final fast = search;
      search = (q) => pending.future;
      await open(tester, theme: AppTheme.light());

      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);
      expect(statusBar(tester)?.statusBarBrightness, Brightness.light);

      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.light);
      expect(statusBar(tester)?.statusBarBrightness, Brightness.dark);

      pending.complete(await fast(const FlightSearchQuery()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flights-results')), findsOneWidget);
      // Le bug : le style clair de l'attente restait sur les résultats.
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);
      expect(statusBar(tester)?.statusBarColor, Colors.transparent);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      await tester.tap(find.byKey(const Key('flights-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flights-destination')));
      await tester.pumpAndSettle();
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.light);

      await tester.tap(find.byKey(const Key('flight-city-DKR')));
      await tester.pumpAndSettle();
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('thème sombre : icônes claires partout', (tester) async {
      await open(tester, theme: AppTheme.dark());
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.light);

      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flights-results')), findsOneWidget);
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.light);
      expect(statusBar(tester)?.statusBarBrightness, Brightness.dark);
    });

    testWidgets('thème sans style de barre : repli sur le défaut Material', (
      tester,
    ) async {
      await open(tester);
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);
    });
  });

  group('dates proches', () {
    FlightSearchResult nearby({int? window}) => FlightSearchResult.fromJson({
      'originCode': 'PAR',
      'destinationCode': 'ABJ',
      'roundTrip': false,
      'currency': 'EUR',
      'nearbyDates': true,
      'nearbyDaysWindow': ?window,
      'offers': const [
        {
          'originCode': 'PAR',
          'destinationCode': 'ABJ',
          'departureAt': '2026-12-15T11:45:00+01:00',
          'price': 431,
          'currency': 'EUR',
          'airlineName': 'Corsair',
          'transfers': 0,
          'offerPath': 'n1',
        },
      ],
    });

    testWidgets('bandeau en tête et date du départ sur la carte', (
      tester,
    ) async {
      search = (_) async => nearby();
      await open(tester);
      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('flights-nearby-dates')), findsOneWidget);
      expect(
        find.text(
          'Pas de prix exact pour ces dates. Voici des vols à 3 jours près.',
        ),
        findsOneWidget,
      );
      expect(find.text('mar. 15 déc.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('écart donné par le back, en anglais', (tester) async {
      enableEnglish();
      search = (_) async => nearby(window: 1);
      await open(tester, locale: const Locale('en'));
      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No exact price for these dates. Here are flights within 1 day.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tue, Dec 15'), findsOneWidget);
    });

    testWidgets('résultats exacts : ni bandeau ni date', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('flights-nearby-dates')), findsNothing);
      expect(find.byKey(const Key('flight-leg-date')), findsNothing);
      expect(find.byKey(const Key('flight-leg-date-shifted')), findsNothing);
    });
  });

  testWidgets('formulaire prérempli et bons plans, puis résultats en cartes', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Billets'), findsOneWidget);
    expect(rich('PAR · Paris'), findsOneWidget);
    expect(rich('ABJ · Abidjan'), findsOneWidget);
    expect(find.byType(FlightDealCard), findsOneWidget);
    expect(find.byKey(const Key('flights-recents')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(FlightOfferCard), findsWidgets);
    expect(find.byKey(const Key('flights-results')), findsOneWidget);
    // Onglet et pastille de carte.
    expect(find.text('Le moins cher'), findsNWidgets(2));
    expect(find.text('Le plus rapide'), findsNWidgets(2));
    expect(
      find.text('4 vols · prix par personne, aller simple'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('flights-all-airlines-inline')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('flights-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-stops-any')), findsOneWidget);
    expect(find.byKey(const Key('flight-slot-morning')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choix de la ville en plein écran, puis mois entier', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('flights-destination')));
    await tester.pumpAndSettle();
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    expect(find.text('DESTINATIONS DE LA DIASPORA'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-city-DKR')));
    await tester.pumpAndSettle();
    expect(find.text('Où allez-vous ?'), findsNothing);
    // Pays du catalogue de l'app, en l'absence de nom renvoyé par le back.
    expect(rich('DKR · Dakar, Sénégal'), findsOneWidget);

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

  testWidgets('inverser, case des vols directs et aller-retour sans retour', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('flights-swap')));
    await tester.pumpAndSettle();
    expect(rich('ABJ · Abidjan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flights-direct')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flights-trip-roundtrip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flights-return-date')), findsOneWidget);
    expect(find.text('Choisir les dates'), findsOneWidget);

    // Le bouton ouvre d'abord la feuille des dates, sur le retour.
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Quand partez-vous ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-dates-validate')));
    await tester.pumpAndSettle();
    verifyNever(() => repository.search(any()));

    await tester.tap(find.byKey(const Key('flights-trip-oneway')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flights-return-date')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('créer une alerte depuis les résultats ouvre la feuille', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flights-create-alert')));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle alerte'), findsOneWidget);
    expect(find.byKey(const Key('flight-alert-submit')), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flights-alert-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle alerte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onglets de tri, puces et retour au formulaire avec historique', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flights-tab-direct')));
    await tester.pumpAndSettle();
    expect(find.byType(FlightOfferCard), findsOneWidget);
    expect(find.byKey(const Key('flight-open-b')), findsOneWidget);

    await tester.tap(find.byKey(const Key('flights-chip-stops')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-stops-oneMax')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-filters-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Filtres · 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flights-summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flights-form')), findsOneWidget);
    expect(find.text('Vos recherches'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('flights-recent-0')),
        matching: find.textContaining('431'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('flights-recent-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flights-results')), findsOneWidget);
    verify(() => repository.search(any())).called(2);

    await tester.tap(find.byKey(const Key('flights-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flights-recent-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Vos recherches'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aucun vol : suggestions concrètes, Paris relance la recherche', (
    tester,
  ) async {
    defaults = const FlightDefaults(
      source: 'search',
      origin: _lille,
      destination: _abidjan,
    );
    final sent = <FlightSearchQuery>[];
    search = (q) async {
      sent.add(q);
      return const FlightSearchResult(
        originCode: 'LIL',
        destinationCode: 'ABJ',
        roundTrip: false,
        currency: 'EUR',
        offers: [],
        searchPath: '/search/LIL1210ABJ1',
      );
    };
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-departure-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-dates-validate')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('Aucun vol à ces dates'), findsOneWidget);
    expect(find.text('Essayez plutôt'), findsOneWidget);
    expect(find.byKey(const Key('flights-suggest-paris')), findsOneWidget);
    expect(find.byKey(const Key('flights-suggest-aviasales')), findsOneWidget);
    expect(find.byKey(const Key('flights-suggest-alert')), findsOneWidget);
    expect(find.byKey(const Key('flights-create-alert')), findsNothing);

    await tester.tap(find.byKey(const Key('flights-suggest-paris')));
    await tester.pumpAndSettle();
    expect(sent.last.origin?.code, 'PAR');

    await tester.tap(find.byKey(const Key('flights-suggest-alert')));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle alerte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erreur du back : « Réessayer » relance', (tester) async {
    var calls = 0;
    search = (_) async {
      calls++;
      throw DioException(
        requestOptions: RequestOptions(),
        error: const NetworkException('down', code: 'flights-unavailable'),
      );
    };
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('Recherche impossible'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flights-retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back ancien : pas de chemin Aviasales, pas d\'encart', (
    tester,
  ) async {
    search = (_) async => FlightSearchResult(
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      offers: [_rich('a', 431, transfers: 1, minutes: 585)],
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(FlightOfferCard), findsOneWidget);
    expect(find.byKey(const Key('flights-all-airlines')), findsNothing);
    expect(find.byKey(const Key('flights-all-airlines-inline')), findsNothing);
    // Une seule offre : ni pastille « Le moins cher » ni « Le plus rapide ».
    expect(find.text('Le moins cher'), findsOneWidget);
  });

  testWidgets('en anglais', (tester) async {
    enableEnglish();
    await open(tester, locale: const Locale('en'));
    expect(find.text('Search flights'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('4 flights · price per person, one way'), findsOneWidget);
    expect(find.text('Cheapest'), findsNWidgets(2));
  });

  testWidgets('attente, puis offres et encart : un lien refusé prévient', (
    tester,
  ) async {
    final pending = Completer<FlightSearchResult>();
    final fast = search;
    search = (q) => pending.future;
    when(
      () => repository.affiliateLink(any(), source: any(named: 'source')),
    ).thenThrow(Exception('offline'));
    await open(tester);

    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Recherche de vols vers Abidjan'), findsOneWidget);

    pending.complete(await fast(const FlightSearchQuery()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flights-results')), findsOneWidget);

    await tester.tap(find.byKey(const Key('flight-open-a')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    final more = find.byKey(const Key('flights-all-airlines-inline'));
    await tester.scrollUntilVisible(
      more,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('flights-results')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    verify(() => repository.affiliateLink(any(), source: 'search')).called(2);
  });

  testWidgets('bon plan et cloche des alertes', (tester) async {
    await open(tester);
    await tester.tap(find.byType(FlightDealCard).first);
    await tester.pumpAndSettle();
    verify(() => repository.search(any())).called(1);

    await tester.tap(find.byKey(const Key('flights-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flights-alerts-button')));
    await tester.pumpAndSettle();
    expect(find.text('alertes'), findsOneWidget);
  });

  testWidgets('aucun vol : tout le mois, puis toutes les compagnies', (
    tester,
  ) async {
    final sent = <FlightSearchQuery>[];
    search = (q) async {
      sent.add(q);
      return const FlightSearchResult(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        roundTrip: false,
        currency: 'EUR',
        offers: [],
        searchPath: '/search/PAR1210ABJ1',
      );
    };
    when(
      () => repository.affiliateLink(any(), source: any(named: 'source')),
    ).thenThrow(Exception('offline'));
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-departure-date')));
    await tester.pumpAndSettle();
    // Mois suivant : tous ses jours sont à venir, quelle que soit la date.
    await tester.tap(find.byTooltip('Mois suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-dates-validate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();
    expect(sent.last.departure?.wholeMonth, isFalse);

    await tester.tap(find.byKey(const Key('flights-suggest-month')));
    await tester.pumpAndSettle();
    expect(sent.last.departure?.wholeMonth, isTrue);

    // Le mois entier n'a rien donné non plus : la suggestion disparaît.
    expect(find.byKey(const Key('flights-suggest-month')), findsNothing);
    await tester.tap(find.byKey(const Key('flights-suggest-aviasales')));
    await tester.pumpAndSettle();
    verify(() => repository.affiliateLink(any(), source: 'search')).called(1);
  });
}
