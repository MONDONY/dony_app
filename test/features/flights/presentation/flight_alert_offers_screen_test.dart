import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/flights/bloc/flight_alert_offers_cubit.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_alert_offers.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/flight_alert_offers_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../bloc/flights_test_doubles.dart';

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

final _alert = FlightAlert(
  id: 'a1',
  originCode: 'PAR',
  destinationCode: 'ABJ',
  originLabel: 'Paris',
  destinationLabel: 'Abidjan',
  departureFrom: DateTime(2099, 12),
  departureTo: DateTime(2099, 12, 20),
  directOnly: false,
  maxPrice: 450,
  currency: 'EUR',
  active: true,
  lastSeenPrice: 389,
  matchCount: 2,
);

FlightAlertOffers _result({
  List<FlightOffer>? offers,
  String? searchPath = '/search/PAR0112ABJ1',
  int? belowCount,
}) => FlightAlertOffers(
  alertId: 'a1',
  originCode: 'PAR',
  destinationCode: 'ABJ',
  originLabel: 'Paris',
  destinationLabel: 'Abidjan',
  roundTrip: false,
  currency: 'EUR',
  maxPrice: 450,
  offers:
      offers ??
      [
        offer('/search/a', price: 389, departureAt: DateTime(2099, 12, 12, 6)),
        offer('/search/b', price: 450, departureAt: DateTime(2099, 12, 16, 11)),
      ],
  searchPath: searchPath,
  belowCount: belowCount,
);

const _aboveAlert = FlightAlert(
  id: 'a1',
  originCode: 'PAR',
  destinationCode: 'ABJ',
  originLabel: 'Paris',
  destinationLabel: 'Abidjan',
  directOnly: false,
  maxPrice: 450,
  currency: 'EUR',
  active: true,
  lastSeenPrice: 470,
  matchCount: 0,
);

/// Texte affiché, espaces insécables ramenées à des espaces simples.
Finder _text(String expected) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.replaceAll(RegExp('[  ]'), ' ') == expected,
);

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;
  late _MockLauncher launcher;

  setUpAll(() {
    registerFallbackValue(
      const FlightOffer(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        price: 0,
        currency: 'EUR',
        offerPath: '/search/x',
      ),
    );
    registerFallbackValue(Uri());
  });

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
    launcher = _MockLauncher();
    when(() => launcher.open(any())).thenAnswer((_) async => true);
    when(
      () => repository.affiliateLink(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => 'https://partner.test/x');
    if (getIt.isRegistered<FlightAlertOffersCubit>()) {
      getIt.unregister<FlightAlertOffersCubit>();
    }
    getIt.registerFactoryParam<
      FlightAlertOffersCubit,
      FlightAlertOffersArgs,
      void
    >(
      (a, _) => FlightAlertOffersCubit(
        repository,
        analytics,
        alertId: a.alertId,
        alert: a.alert,
        source: a.source,
      ),
    );
    if (getIt.isRegistered<FlightLinkCubit>()) {
      getIt.unregister<FlightLinkCubit>();
    }
    getIt.registerFactory<FlightLinkCubit>(
      () => FlightLinkCubit(repository, analytics, launcher),
    );
  });

  tearDown(() {
    getIt
      ..unregister<FlightAlertOffersCubit>()
      ..unregister<FlightLinkCubit>();
  });

  Future<void> open(
    WidgetTester tester, {
    FlightAlert? alert,
    bool asRoot = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: asRoot ? '/flights/alerts/a1/offers' : '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  context.push('/flights/alerts/a1/offers', extra: alert),
              child: const Text('ouvrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/flights/alerts',
          builder: (_, _) => const Scaffold(body: Text('mes alertes')),
          routes: [
            GoRoute(
              path: ':id/offers',
              builder: (_, state) => FlightAlertOffersScreen(
                alertId: state.pathParameters['id']!,
                alert: state.extra is FlightAlert
                    ? state.extra! as FlightAlert
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    if (!asRoot) {
      await tester.tap(find.text('ouvrir'));
      await tester.pump();
    }
  }

  testWidgets('chargement puis vols : résumé, bandeau, écarts, dates', (
    tester,
  ) async {
    final pending = Completer<FlightAlertOffers>();
    when(() => repository.alertOffers('a1')).thenAnswer((_) => pending.future);
    await open(tester, alert: _alert);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('flight-alert-offers-loading')), findsOne);

    pending.complete(_result());
    await tester.pumpAndSettle();

    expect(find.text('Vols trouvés'), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(
      _text('Départ du 1 déc. au 20 déc. 2099 · Aller simple · prix max 450 €'),
      findsOneWidget,
    );
    expect(
      _text('2 vols sous votre prix, le moins cher à 389 €'),
      findsOneWidget,
    );
    expect(_text('−61 € sous votre prix'), findsOneWidget);
    expect(find.text('à votre prix'), findsOneWidget);
    expect(find.text('Le moins cher'), findsNothing);
    expect(find.byKey(const Key('flight-leg-date')), findsNWidgets(2));
    expect(find.byKey(const Key('flight-alert-offers-aviasales')), findsOne);
    expect(find.text('Plus de vols sur Aviasales'), findsOneWidget);
  });

  testWidgets('scope=all : section « Au-dessus de votre prix » après', (
    tester,
  ) async {
    when(() => repository.alertOffers('a1')).thenAnswer(
      (_) async => _result(
        offers: [
          offer('/search/a', price: 389, departureAt: DateTime(2099, 12, 2)),
          offer('/search/c', price: 473.4, departureAt: DateTime(2099, 12, 5)),
          offer('/search/d', price: 450.2, departureAt: DateTime(2099, 12, 9)),
        ]..sort((a, b) => a.price.compareTo(b.price)),
        belowCount: 1,
      ),
    );
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();

    expect(find.text('Vols trouvés'), findsOneWidget);
    expect(_text('1 vol sous votre prix, à 389 €'), findsOneWidget);
    expect(find.text('Au-dessus de votre prix'), findsOneWidget);
    expect(find.byKey(const Key('flight-offer-savings')), findsOneWidget);
    expect(find.byKey(const Key('flight-offer-above')), findsNWidgets(2));
    expect(_text('+1 € au-dessus'), findsOneWidget);
    expect(_text('+24 € au-dessus'), findsOneWidget);
    expect(find.byKey(const Key('flight-leg-date')), findsNWidgets(3));
    // Ordre : vol sous le prix, titre, vols au-dessus, encart Aviasales.
    final y = [
      find.byKey(const Key('flight-open-/search/a')),
      find.byKey(const Key('flight-alert-offers-above-title')),
      find.byKey(const Key('flight-open-/search/d')),
      find.byKey(const Key('flight-alert-offers-aviasales')),
    ].map((f) => tester.getTopLeft(f).dy).toList();
    expect(y, orderedEquals([...y]..sort()));
  });

  testWidgets('aucun vol sous le prix : bandeau neutre, titre de l\'alerte', (
    tester,
  ) async {
    final pending = Completer<FlightAlertOffers>();
    when(() => repository.alertOffers('a1')).thenAnswer((_) => pending.future);
    await open(tester, alert: _aboveAlert);
    await tester.pump(const Duration(milliseconds: 400));
    // Pendant le chargement, l'alerte sans vol sous le prix donne le titre.
    expect(find.text('Vols de votre alerte'), findsOneWidget);

    pending.complete(
      _result(
        offers: [
          offer('/search/c', price: 470, departureAt: DateTime(2099, 12, 5)),
          offer('/search/d', price: 520, departureAt: DateTime(2099, 12, 9)),
        ],
        belowCount: 0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vols de votre alerte'), findsOneWidget);
    expect(find.text('Vols trouvés'), findsNothing);
    expect(find.byKey(const Key('flight-alert-offers-banner')), findsNothing);
    expect(
      _text(
        "Aucun vol sous votre prix pour l'instant, le moins cher est à 470 €",
      ),
      findsOneWidget,
    );
    expect(find.text('Au-dessus de votre prix'), findsOneWidget);
    expect(find.byKey(const Key('flight-offer-savings')), findsNothing);
    expect(find.byKey(const Key('flight-offer-above')), findsNWidgets(2));
    expect(find.byKey(const Key('flight-alert-offers-aviasales')), findsOne);
  });

  testWidgets('toucher une offre : lien affilié, source alerte', (
    tester,
  ) async {
    when(() => repository.alertOffers('a1')).thenAnswer((_) async => _result());
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flight-open-/search/a')));
    await tester.pumpAndSettle();

    final captured = verify(
      () => repository.affiliateLink(captureAny(), source: 'alert'),
    ).captured;
    expect((captured.single as FlightOffer).offerPath, '/search/a');
    verify(() => launcher.open(Uri.parse('https://partner.test/x'))).called(1);
  });

  testWidgets('encart Aviasales : recherche du trajet ; échec signalé', (
    tester,
  ) async {
    when(() => repository.alertOffers('a1')).thenAnswer((_) async => _result());
    when(
      () => repository.affiliateLink(any(), source: any(named: 'source')),
    ).thenThrow(Exception('offline'));
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flight-alert-offers-aviasales')));
    await tester.pumpAndSettle();

    final captured = verify(
      () => repository.affiliateLink(captureAny(), source: 'search'),
    ).captured;
    expect((captured.single as FlightOffer).offerPath, '/search/PAR0112ABJ1');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('plus rien sous le prix : message et Aviasales en direct', (
    tester,
  ) async {
    when(
      () => repository.alertOffers('a1'),
    ).thenAnswer((_) async => _result(offers: const []));
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flight-alert-offers-empty')), findsOne);
    expect(find.text('Vols de votre alerte'), findsOneWidget);
    expect(
      find.text("Plus de vol sous votre prix pour l'instant"),
      findsOneWidget,
    );
    expect(find.byKey(const Key('flight-alert-offers-summary')), findsOne);
    await tester.tap(find.byKey(const Key('flights-suggest-aviasales')));
    await tester.pumpAndSettle();
    verify(() => repository.affiliateLink(any(), source: 'search')).called(1);
  });

  testWidgets('back récent sans aucun vol : « Aucun vol trouvé »', (
    tester,
  ) async {
    when(
      () => repository.alertOffers('a1'),
    ).thenAnswer((_) async => _result(offers: const [], belowCount: 0));
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flight-alert-offers-empty')), findsOne);
    expect(find.text('Vols de votre alerte'), findsOneWidget);
    expect(find.text("Aucun vol trouvé pour l'instant"), findsOneWidget);
    expect(
      find.textContaining('Aucun prix disponible pour ce trajet'),
      findsOneWidget,
    );
    expect(
      find.text("Plus de vol sous votre prix pour l'instant"),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('flights-suggest-aviasales')));
    await tester.pumpAndSettle();
    verify(() => repository.affiliateLink(any(), source: 'search')).called(1);
  });

  testWidgets('404 (ancien back) : vide, Aviasales depuis l\'alerte', (
    tester,
  ) async {
    when(() => repository.alertOffers('a1')).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        error: const NotFoundException(),
      ),
    );
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flight-alert-offers-empty')), findsOne);
    await tester.tap(find.byKey(const Key('flights-suggest-aviasales')));
    await tester.pumpAndSettle();
    final captured = verify(
      () => repository.affiliateLink(captureAny(), source: 'search'),
    ).captured;
    expect(
      (captured.single as FlightOffer).offerPath,
      startsWith('/search/PAR'),
    );
  });

  testWidgets('404 sans alerte connue : pas de bouton Aviasales', (
    tester,
  ) async {
    when(() => repository.alertOffers('a1')).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        error: const NotFoundException(),
      ),
    );
    when(() => repository.alerts()).thenAnswer((_) async => const []);
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flight-alert-offers-empty')), findsOne);
    expect(find.byKey(const Key('flight-alert-offers-summary')), findsNothing);
    expect(find.byKey(const Key('flights-suggest-aviasales')), findsNothing);
  });

  testWidgets('erreur : réessayer recharge', (tester) async {
    var calls = 0;
    when(() => repository.alertOffers('a1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return _result();
    });
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-alert-offers-error')), findsOne);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-alert-offers-list')), findsOne);
  });

  testWidgets('retour : dépile, ou rouvre Mes alertes sans pile', (
    tester,
  ) async {
    when(() => repository.alertOffers('a1')).thenAnswer((_) async => _result());
    when(() => repository.alerts()).thenAnswer((_) async => [_alert]);
    await open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-alert-offers-back')));
    await tester.pumpAndSettle();
    expect(find.text('ouvrir'), findsOneWidget);

    await open(tester, asRoot: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flight-alert-offers-back')));
    await tester.pumpAndSettle();
    expect(find.text('mes alertes'), findsOneWidget);
  });

  test('chemin de l\'écran, depuis la liste ou une notification', () {
    expect(flightAlertOffersLocation('a1'), '/flights/alerts/a1/offers');
    expect(
      flightAlertOffersLocation('a1', notification: true),
      '/flights/alerts/a1/offers?source=notification',
    );
  });

  testWidgets('alerte sans période : encart Aviasales au jour du moins cher', (
    tester,
  ) async {
    when(
      () => repository.alertOffers('a1'),
    ).thenAnswer((_) async => _result(searchPath: null));
    await open(tester, alert: _alert);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Toutes les compagnies, prix du moment, à la date du vol le moins cher.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('flight-alert-offers-aviasales')));
    await tester.pumpAndSettle();
    final captured = verify(
      () => repository.affiliateLink(captureAny(), source: 'search'),
    ).captured;
    expect((captured.single as FlightOffer).offerPath, '/search/PAR1212ABJ1');
  });
}
