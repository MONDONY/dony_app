import 'package:dony/core/config/flights_flag.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/presentation/widgets/flight_price_ticket.dart';
import 'package:dony/features/matching/presentation/widgets/activites_flight_alerts_row.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../flights/bloc/flights_test_doubles.dart';

class _Probe implements FirebaseSessionProbe {
  const _Probe({required this.real});

  final bool real;

  @override
  bool get hasSession => true;
  @override
  bool get isAnonymous => !real;
  @override
  bool get hasRealSession => real;
}

FlightAlert _alert(
  String id, {
  double max = 450,
  double? seen,
  int? count,
  List<String> codes = const [],
  bool active = true,
  String from = 'Paris',
  String to = 'Abidjan',
}) => FlightAlert(
  id: id,
  originCode: 'PAR',
  destinationCode: 'ABJ',
  originLabel: from,
  destinationLabel: to,
  directOnly: false,
  maxPrice: max,
  currency: 'EUR',
  active: active,
  lastSeenPrice: seen,
  lastCheckedAt: seen == null ? null : DateTime(2026, 10, 13),
  matchCount: count,
  matchAirlineCodes: codes,
);

/// Texte affiché, espaces insécables ramenées à des espaces simples (le
/// format des prix en met une avant « € »).
Finder _text(String expected) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      w.data?.replaceAll(RegExp('[\u00a0\u202f]'), ' ') == expected,
);

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;
  late FlightAlertsCubit cubit;

  void probe({required bool real}) {
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      getIt.unregister<FirebaseSessionProbe>();
    }
    getIt.registerSingleton<FirebaseSessionProbe>(_Probe(real: real));
  }

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
    cubit = FlightAlertsCubit(repository, analytics);
    resetFlightsFlagForTest();
    setFlightsEnabled(true);
    probe(real: true);
  });

  tearDown(() async {
    await cubit.close();
    resetFlightsFlagForTest();
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      getIt.unregister<FirebaseSessionProbe>();
    }
  });

  late List<String> pushed;

  Widget app() {
    pushed = [];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: ActivitesFlightAlertsRow(),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/flights/alerts',
          builder: (_, state) {
            pushed.add(state.uri.toString());
            return const Scaffold(body: Text('mes alertes'));
          },
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

  Future<void> pump(WidgetTester tester, List<FlightAlert> alerts) async {
    when(() => repository.alerts()).thenAnswer((_) async => alerts);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  testWidgets('flag éteint : rien, aucun appel', (tester) async {
    setFlightsEnabled(false);
    await pump(tester, const []);

    expect(find.byKey(const Key('hub-flight-alerts-row')), findsNothing);
    verifyNever(() => repository.alerts());
  });

  testWidgets('visiteur : rien', (tester) async {
    probe(real: false);
    await pump(tester, const []);

    expect(find.byKey(const Key('hub-flight-alerts-row')), findsNothing);
    verifyNever(() => repository.alerts());
  });

  testWidgets('flag allumé après le montage : la ligne apparaît et charge', (
    tester,
  ) async {
    setFlightsEnabled(false);
    await pump(tester, const []);
    setFlightsEnabled(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hub-flight-alerts-empty')), findsOneWidget);
    verify(() => repository.alerts()).called(1);
  });

  testWidgets('un prix trouvé : logos, trajet, vols et billet vert', (
    tester,
  ) async {
    await pump(tester, [
      _alert('a', seen: 389, count: 3, codes: const ['AT', 'SS', 'AF']),
      _alert('b', max: 300, seen: 412, count: 0),
    ]);

    expect(find.byKey(const Key('hub-flight-alerts-hit')), findsOneWidget);
    expect(find.byKey(const Key('hub-flight-alerts-icon-hit')), findsOneWidget);
    expect(find.text('Alertes prix vols'), findsOneWidget);
    expect(find.byKey(const Key('airline-logo-stack')), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(find.text(' · 3 vols'), findsOneWidget);
    expect(find.byKey(const Key('hub-flight-alerts-ticket-hit')), findsOne);
    expect(_text('389 €'), findsOneWidget);
    expect(_text('−61 € sous votre prix'), findsOneWidget);
  });

  testWidgets('prix pile au seuil, sans nombre ni compagnies (ancien back)', (
    tester,
  ) async {
    await pump(tester, [_alert('a', seen: 450)]);

    expect(find.byKey(const Key('hub-flight-alerts-hit')), findsOneWidget);
    expect(find.byKey(const Key('airline-logo-stack')), findsNothing);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    expect(find.text('à votre prix'), findsOneWidget);
  });

  testWidgets('plusieurs alertes ont trouvé : « 2 alertes · dès »', (
    tester,
  ) async {
    await pump(tester, [
      _alert('a', seen: 389, count: 3, codes: const ['AT']),
      _alert('b', max: 300, seen: 280, count: 1),
    ]);

    expect(_text('2 alertes · dès 280 €'), findsOneWidget);
    expect(find.byKey(const Key('airline-logo-stack')), findsNothing);
    expect(_text('280 €'), findsOneWidget);
    expect(_text('−20 € sous votre prix'), findsOneWidget);
  });

  testWidgets('prix trouvé sans prix connu : flèche à la place du billet', (
    tester,
  ) async {
    await pump(tester, [_alert('a', count: 2)]);

    expect(find.byKey(const Key('hub-flight-alerts-hit')), findsOneWidget);
    expect(find.byType(FlightPriceTicket), findsNothing);
  });

  testWidgets('rien sous le seuil : alertes actives et billet gris', (
    tester,
  ) async {
    await pump(tester, [
      _alert('a', seen: 512, count: 0),
      _alert('b', max: 300, seen: 412, count: 0),
    ]);

    expect(find.byKey(const Key('hub-flight-alerts-no_hit')), findsOneWidget);
    expect(find.byKey(const Key('hub-flight-alerts-icon')), findsOneWidget);
    expect(find.text('2 alertes actives'), findsOneWidget);
    expect(find.byKey(const Key('hub-flight-alerts-ticket-neutral')), findsOne);
    expect(_text('412 €'), findsOneWidget);
    expect(find.text('meilleur prix vu'), findsOneWidget);
  });

  testWidgets('rien de vérifié : pas de billet, juste la flèche', (
    tester,
  ) async {
    await pump(tester, [_alert('a'), _alert('b', active: false)]);

    expect(find.text('1 alerte active'), findsOneWidget);
    expect(find.byType(FlightPriceTicket), findsNothing);
  });

  testWidgets('aucune alerte : billet « Créer » qui ouvre la feuille', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(tester, const []);

    expect(find.byKey(const Key('hub-flight-alerts-empty')), findsOneWidget);
    expect(find.text("Être prévenu d'une baisse de prix"), findsOneWidget);
    expect(find.text('Créer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hub-flight-alerts-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-alert-submit')), findsOneWidget);
    expect(pushed, isEmpty);
  });

  testWidgets('chargement : squelette discret', (tester) async {
    when(() => repository.alerts()).thenAnswer(
      (_) => Future.delayed(const Duration(seconds: 1), () => const []),
    );
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byKey(const Key('hub-flight-alerts-loading')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hub-flight-alerts-empty')), findsOneWidget);
  });

  testWidgets('échec : ligne neutre sans billet, qui mène aux alertes', (
    tester,
  ) async {
    when(() => repository.alerts()).thenThrow(Exception('offline'));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hub-flight-alerts-error')), findsOneWidget);
    expect(find.byType(FlightPriceTicket), findsNothing);

    await tester.tap(find.byKey(const Key('hub-flight-alerts-row')));
    await tester.pumpAndSettle();
    expect(pushed, ['/flights/alerts']);
  });

  testWidgets(
    'toucher la ligne : état tracé, Mes alertes, rechargé au retour',
    (tester) async {
      await pump(tester, [_alert('a', seen: 389, count: 3)]);

      await tester.tap(find.byKey(const Key('hub-flight-alerts-row')));
      await tester.pumpAndSettle();
      expect(find.text('mes alertes'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.activitesHubFlightAlertsOpened,
          properties: {'state': 'hit'},
        ),
      ).called(1);

      when(() => repository.alerts()).thenAnswer((_) async => const []);
      GoRouter.of(tester.element(find.text('mes alertes'))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hub-flight-alerts-empty')), findsOneWidget);
    },
  );
}
