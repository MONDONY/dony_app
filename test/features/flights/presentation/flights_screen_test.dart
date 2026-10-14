import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_feedback_button.dart';
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
import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:dony/features/flights/presentation/flight_city_picker_screen.dart';
import 'package:dony/features/flights/presentation/flights_screen.dart';
import 'package:dony/features/flights/presentation/widgets/flight_deal_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_offer_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_results_parts.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      GoRoute(
        path: '/announcements',
        builder: (_, _) => const Scaffold(body: Text('hub Activités')),
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
    registerFallbackValue(FlightPassengers.single);
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
    testWidgets('icônes sombres partout en thème clair : l\'en-tête Yadony '
        'clair couvre aussi l\'attente et le choix de ville', (tester) async {
      final pending = Completer<FlightSearchResult>();
      final fast = search;
      search = (q) => pending.future;
      await open(tester, theme: AppTheme.light());

      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);

      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('flights-loading')), findsOneWidget);
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);

      pending.complete(await fast(const FlightSearchQuery()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flights-results')), findsOneWidget);
      // Le bug d'origine : un style clair posé par un écran restait sur
      // les résultats.
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);
      expect(statusBar(tester)?.statusBarColor, Colors.transparent);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      await tester.tap(find.byType(DonyAppBarBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flights-destination')));
      await tester.pumpAndSettle();
      expect(find.byType(FlightCityPickerScreen), findsOneWidget);
      expect(statusBar(tester)?.statusBarIconBrightness, Brightness.dark);

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

    testWidgets('résultats exacts : pas de bandeau, la date du vol sur chaque '
        'carte sans mise en évidence', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('flights-nearby-dates')), findsNothing);
      expect(find.byKey(const Key('flight-leg-date')), findsWidgets);
      expect(find.text('sam. 12 déc.'), findsWidgets);
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
    expect(find.byKey(const Key('flights-all-airlines-top')), findsOneWidget);
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

  testWidgets('en-tête des résultats : barre Yadony et barre de recherche '
      'sans cadre', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    final header = find.byType(FlightResultsHeader);
    // Barre Yadony : chevron carré, « Résultats » centré, scarabée.
    expect(
      find.descendant(of: header, matching: find.byType(DonyAppBar)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Résultats')),
      findsOneWidget,
    );
    final bar = tester.widget<AppBar>(
      find.descendant(of: header, matching: find.byType(AppBar)),
    );
    expect(bar.centerTitle, isTrue);
    final back = find.descendant(
      of: header,
      matching: find.byType(DonyAppBarBackButton),
    );
    expect(
      tester.getCenter(back).dx,
      lessThan(tester.getCenter(find.text('Résultats')).dx),
    );
    expect(
      tester.getCenter(find.byType(DonyFeedbackButton)).dx,
      greaterThan(tester.getCenter(find.text('Résultats')).dx),
    );
    // Barre de recherche : trajet, crayon, dates, passagers.
    expect(
      tester.widget<Text>(find.byKey(const Key('flights-summary-route'))).data,
      'Paris → Abidjan',
    );
    expect(find.byKey(const Key('flights-summary-edit')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('flights-summary-dates'))).data,
      'Toutes les dates',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('flights-summary-passengers')))
          .data,
      '1',
    );
    // Sans cadre : ni bordure ni fond propre autour du résumé.
    expect(
      find.descendant(
        of: find.byKey(const Key('flights-summary')),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('flights-summary'))),
      matchesSemantics(
        isButton: true,
        label: 'Paris → Abidjan',
        value: 'Toutes les dates, 1 passager',
        hint: 'Modifier la recherche',
        hasTapAction: true,
      ),
    );

    // Toucher la barre de recherche ramène au formulaire.
    await tester.tap(find.byKey(const Key('flights-summary-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flights-form')), findsOneWidget);
  });

  testWidgets('passagers : feuille, résumé, en-tête, prix et lien', (
    tester,
  ) async {
    FlightPassengers? sent;
    when(
      () => repository.affiliateLink(
        any(),
        source: any(named: 'source'),
        passengers: any(named: 'passengers'),
      ),
    ).thenAnswer((inv) async {
      sent = inv.namedArguments[#passengers] as FlightPassengers;
      throw Exception('offline');
    });
    await open(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('flights-passengers-value')))
          .data,
      '1 adulte',
    );

    await tester.tap(find.byKey(const Key('flights-passengers')));
    await tester.pumpAndSettle();
    expect(find.text('Qui voyage ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flight-passengers-adults-plus')));
    await tester.tap(find.byKey(const Key('flight-passengers-children-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('flight-passengers-validate')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('flights-passengers-value')))
          .data,
      '2 adultes, 1 enfant',
    );

    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('flights-summary-passengers')))
          .data,
      '3',
    );
    // Enfant dans la recherche : prix par adulte, pas de total estimé.
    expect(find.byKey(const Key('flight-offer-per-adult')), findsWidgets);
    expect(find.text('par adulte'), findsWidgets);
    expect(find.text('Prix final sur Aviasales'), findsWidgets);

    await tester.tap(find.byKey(const Key('flight-open-a')));
    await tester.pumpAndSettle();
    expect(sent, const FlightPassengers(adults: 2, children: 1));
  });

  testWidgets('adultes seuls : total estimé sous le prix par adulte', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-passengers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-passengers-adults-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('flight-passengers-validate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('par adulte'), findsWidgets);
    expect(
      find.textContaining(RegExp(r'^≈ 862.€ pour 2 pers\.$')),
      findsOneWidget,
    );
    expect(find.text('Prix final sur Aviasales'), findsNothing);
  });

  testWidgets('résultats : scarabée seul en haut, alerte par le bouton bas', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    // Plus de cloche dans l'en-tête des résultats : seul le scarabée reste.
    expect(find.byKey(const Key('flights-create-alert')), findsNothing);
    expect(find.byKey(const Key('flights-alerts-button')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FlightResultsHeader),
        matching: find.byType(DonyFeedbackButton),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FlightResultsHeader),
        matching: find.byType(DonyAppBarBackButton),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('flights-alert-fab')));
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

    await tester.tap(find.byType(DonyAppBarBackButton));
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
    expect(
      find.descendant(
        of: find.byType(FlightResultsHeader),
        matching: find.byType(DonyFeedbackButton),
      ),
      findsOneWidget,
    );

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
    expect(find.byKey(const Key('flights-all-airlines-top')), findsNothing);
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

    final more = find.byKey(const Key('flights-all-airlines-top'));
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

    await tester.tap(find.byType(DonyAppBarBackButton));
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
  Future<Finder> resultsFor(
    WidgetTester tester, {
    required int count,
    bool nearby = false,
  }) async {
    search = (_) async => FlightSearchResult(
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      offers: [
        for (var i = 0; i < count; i++)
          _rich('o$i', 400.0 + i * 10, transfers: i % 2, minutes: 400 + i),
      ],
      searchPath: '/search/PAR1212ABJ1',
      nearbyDates: nearby,
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();
    return find.descendant(
      of: find.byKey(const Key('flights-results')),
      matching: find.byType(Scrollable),
    );
  }

  testWidgets('peu de vols : Aviasales mis en avant en tête de liste', (
    tester,
  ) async {
    await resultsFor(tester, count: 2);

    final top = find.byKey(const Key('flights-all-airlines-top'));
    expect(top, findsOneWidget);
    expect(find.text('Plus de vols sur Aviasales'), findsOneWidget);
    // En tête : au-dessus de la première carte.
    expect(
      tester.getTopLeft(top).dy,
      lessThan(tester.getTopLeft(find.byType(FlightOfferCard).first).dy),
    );
    expect(find.byKey(const Key('flights-all-airlines')), findsNothing);
    expect(find.byKey(const Key('flights-all-airlines-inline')), findsNothing);

    await tester.tap(top);
    await tester.pumpAndSettle();
    verify(() => repository.affiliateLink(any(), source: 'search')).called(1);
  });

  testWidgets('beaucoup de vols : encart après la 3e carte et en fin', (
    tester,
  ) async {
    final scrollable = await resultsFor(tester, count: 6);

    expect(find.byKey(const Key('flights-all-airlines-top')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('flights-all-airlines-inline')),
      300,
      scrollable: scrollable,
    );
    expect(
      find.byKey(const Key('flights-all-airlines-inline')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('flights-all-airlines')),
      300,
      scrollable: scrollable,
    );
    expect(find.byKey(const Key('flights-all-airlines')), findsOneWidget);
  });

  testWidgets('dates proches : Aviasales en tête même avec beaucoup de vols', (
    tester,
  ) async {
    await resultsFor(tester, count: 6, nearby: true);

    expect(find.byKey(const Key('flights-nearby-dates')), findsOneWidget);
    expect(find.byKey(const Key('flights-all-airlines-top')), findsOneWidget);
    expect(find.byKey(const Key('flights-all-airlines-inline')), findsNothing);
  });

  testWidgets('aucun vol : bouton principal de recherche en direct', (
    tester,
  ) async {
    search = (_) async => const FlightSearchResult(
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      offers: [],
      searchPath: '/search/PAR1212ABJ1',
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('flights-search-button')));
    await tester.pumpAndSettle();

    final cta = find.byKey(const Key('flights-suggest-aviasales'));
    expect(cta, findsOneWidget);
    expect(find.text('Rechercher en direct sur Aviasales'), findsOneWidget);
    // Avant « Essayez plutôt » : c'est l'action principale.
    expect(
      tester.getTopLeft(cta).dy,
      lessThan(tester.getTopLeft(find.text('Essayez plutôt')).dy),
    );
  });

  group('ouvert depuis Activités', () {
    /// Billets empilé sur le hub, comme dans la branche Activités du shell.
    Widget nested({Object? extra}) {
      final router = GoRouter(
        initialLocation: '/announcements',
        routes: [
          GoRoute(
            path: '/announcements',
            builder: (_, _) => const Scaffold(body: Text('hub Activités')),
            routes: [
              GoRoute(
                path: 'flights',
                builder: (_, state) => FlightsScreen(
                  launch: state.extra is FlightsLaunch
                      ? state.extra! as FlightsLaunch
                      : null,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/flights/alerts',
            builder: (_, _) => const Scaffold(body: Text('alertes')),
          ),
        ],
      );
      return MaterialApp.router(
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      );
    }

    Future<void> openNested(WidgetTester tester, {Object? extra}) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(nested());
      await tester.pumpAndSettle();
      final context = tester.element(find.text('hub Activités'));
      unawaited(
        GoRouter.of(context).push('/announcements/flights', extra: extra),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('en-tête Yadony : retour à gauche du titre, revient au hub', (
      tester,
    ) async {
      await openNested(tester);

      final back = find.byType(DonyAppBarBackButton);
      expect(back, findsOneWidget);
      expect(
        tester.getCenter(back).dx,
        lessThan(tester.getTopLeft(find.text('Billets')).dx),
      );
      // Départ habituel prérempli (GET /flights/defaults).
      expect(rich('PAR · Paris'), findsOneWidget);

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('hub Activités'), findsOneWidget);
      expect(find.byType(FlightsScreen), findsNothing);
    });

    testWidgets('un bon plan du hub lance sa recherche dès l\'ouverture', (
      tester,
    ) async {
      final hubDeal = FlightDeal(
        offer: offer('hub', departureAt: DateTime(2026, 11, 4)),
        medianPrice: 600,
        discountPercent: 48,
      );
      await openNested(
        tester,
        extra: FlightsLaunch(deal: hubDeal, personalized: true),
      );

      final query =
          verify(() => repository.search(captureAny())).captured.single
              as FlightSearchQuery;
      expect(query.origin?.code, 'PAR');
      expect(query.destination?.code, 'ABJ');
      // Le préremplissage n'écrase pas le trajet du bon plan.
      verifyNever(() => repository.defaults());
    });

    testWidgets('serveur muet : départ repris de la dernière recherche', (
      tester,
    ) async {
      defaults = FlightDefaults.none;
      await recents.add(
        FlightRecentSearch(
          origin: _lille,
          destination: _abidjan,
          searchedAt: DateTime(2026, 10),
        ),
      );
      await openNested(tester);

      expect(rich('LIL · Lille'), findsOneWidget);
      expect(rich('ABJ · Abidjan'), findsOneWidget);
    });
  });

  testWidgets('ouvert sans rien à dépiler : retour sur le hub Activités', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byType(DonyAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('hub Activités'), findsOneWidget);
  });

  group('séjours proches', () {
    Map<String, dynamic> roundTrip(String path, String out, String back) => {
      'originCode': 'PAR',
      'destinationCode': 'ABJ',
      'departureAt': '${out}T11:45:00+01:00',
      'returnAt': '${back}T20:10:00+00:00',
      'price': 612,
      'currency': 'EUR',
      'airlineName': 'Air France',
      'transfers': 0,
      'returnTransfers': 0,
      'offerPath': path,
    };

    FlightSearchResult withSimilar({required int offers, bool range = true}) =>
        FlightSearchResult.fromJson({
          'originCode': 'PAR',
          'destinationCode': 'ABJ',
          'roundTrip': true,
          'currency': 'EUR',
          'searchPath': '/search/PAR0212ABJ30121',
          'offers': [
            for (var i = 0; i < offers; i++)
              roundTrip('o$i', '2026-12-02', '2026-12-30'),
          ],
          'similarOffers': [
            roundTrip('s1', '2026-11-20', '2026-12-18'),
            roundTrip('s2', '2027-01-05', '2027-02-02'),
          ],
          if (range) 'similarStayMinDays': 21,
          if (range) 'similarStayMaxDays': 35,
        });

    Future<void> searchWithDates(WidgetTester tester, {Locale? locale}) async {
      await open(tester, locale: locale ?? AppL10n.fr);
      BlocProvider.of<FlightSearchCubit>(
        tester.element(find.byKey(const Key('flights-form'))),
      ).setDates(
        FlightWhen.day(DateTime(2026, 12, 2)),
        FlightWhen.day(DateTime(2026, 12, 30)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pumpAndSettle();
    }

    Finder results() => find
        .descendant(
          of: find.byKey(const Key('flights-results')),
          matching: find.byType(Scrollable),
        )
        .first;

    testWidgets('après la liste : titre, dates en accent, badge, tap similar', (
      tester,
    ) async {
      registerFallbackValue(Uri());
      final analytics = silentAnalytics();
      final launcher = _MockLauncher();
      when(() => launcher.open(any())).thenAnswer((_) async => true);
      when(
        () => repository.affiliateLink(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => 'https://www.aviasales.com/search/S1');
      _register<FlightLinkCubit>(
        () => FlightLinkCubit(repository, analytics, launcher),
      );
      search = (_) async => withSimilar(offers: 1);
      await searchWithDates(tester);

      // Le compteur ne compte que les vols aux dates demandées.
      expect(
        find.text('1 vol · prix par personne, aller-retour'),
        findsOneWidget,
      );
      final section = find.byKey(const Key('flights-similar'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('flights-similar-s1')),
        300,
        scrollable: results(),
      );
      expect(find.text('Séjours de 21 à 35 jours'), findsOneWidget);
      expect(
        find.text(
          'Dates différentes de votre recherche, durée de séjour proche',
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(section).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('flight-open-o0'))).dy,
        ),
      );
      final card = find.byKey(const Key('flights-similar-s1'));
      expect(
        find.descendant(of: card, matching: find.text('28 j')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const Key('flight-leg-date-shifted')),
        ),
        findsNWidgets(2),
      );
      expect(find.text('ven. 20 nov.'), findsOneWidget);

      // Carte suivante visible : la première sort de sous le bouton flottant.
      await tester.scrollUntilVisible(
        find.byKey(const Key('flights-similar-s2')),
        300,
        scrollable: results(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flight-open-s1')));
      await tester.pumpAndSettle();
      verify(() => repository.affiliateLink(any(), source: 'search')).called(1);
      verify(
        () => analytics.logEvent(
          'flights_offer_clicked',
          properties: {
            'source': 'similar',
            'stops': 0,
            'round_trip': true,
            'passengers': 1,
          },
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('beaucoup de vols : section avant l\'encart Aviasales de fin', (
      tester,
    ) async {
      search = (_) async => withSimilar(offers: 6);
      await searchWithDates(tester);

      expect(
        find.text('6 vols · prix par personne, aller-retour'),
        findsOneWidget,
      );
      final end = find.byKey(const Key('flights-all-airlines'));
      await tester.scrollUntilVisible(end, 300, scrollable: results());
      await tester.pumpAndSettle();
      final section = find.byKey(const Key('flights-similar'));
      expect(section, findsOneWidget);
      expect(
        tester.getTopLeft(section).dy,
        lessThan(tester.getTopLeft(end).dy),
      );
    });

    testWidgets('aucun vol : section sous le bloc, avant « Essayez plutôt »', (
      tester,
    ) async {
      search = (_) async => withSimilar(offers: 0);
      await searchWithDates(tester);

      expect(find.byKey(const Key('flights-empty')), findsOneWidget);
      final section = find.byKey(const Key('flights-similar'));
      expect(section, findsOneWidget);
      expect(
        tester.getTopLeft(section).dy,
        greaterThan(tester.getTopLeft(find.text('Aucun vol à ces dates')).dy),
      );
      final tryInstead = find.text('Essayez plutôt');
      await tester.scrollUntilVisible(
        tryInstead,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('flights-empty')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester.getTopLeft(section).dy,
        lessThan(tester.getTopLeft(tryInstead).dy),
      );
      expect(find.byType(FlightOfferCard), findsNWidgets(2));
    });

    testWidgets('en anglais, plage déduite des offres', (tester) async {
      enableEnglish();
      search = (_) async => withSimilar(offers: 0, range: false);
      await searchWithDates(tester, locale: const Locale('en'));

      expect(find.text('28 to 28 day trips'), findsNothing);
      expect(find.text('28 day trips'), findsOneWidget);
      expect(find.text('28 days'), findsNWidgets(2));
    });

    testWidgets('ancien back : pas de section', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('flights-search-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flights-similar')), findsNothing);
      expect(find.byKey(const Key('flight-offer-stay')), findsNothing);
    });
  });
}
