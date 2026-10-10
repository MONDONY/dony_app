import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/bloc/money_trips_cubit.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/screens/money_overview_screen.dart';
import 'package:dony/features/payments/money/presentation/screens/money_trips_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'money_fixtures.dart';

class MockMoneyOverviewBloc
    extends MockBloc<MoneyOverviewEvent, MoneyOverviewState>
    implements MoneyOverviewBloc {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

/// Beaucoup de trajets actifs pour le chargement progressif.
MoneyOverviewModel manyTrips(int count) => MoneyOverviewModel(
  travelerItems: [
    for (var i = 0; i < count; i++)
      item(
        bidId: 'b$i',
        announcementId: 't$i',
        trackingNumber: 'DON-T$i',
        arrivalDate: DateTime(2026, 10, 10 + i),
      ),
  ],
);

void main() {
  late MockMoneyOverviewBloc bloc;
  late MockAnalyticsService analytics;
  late List<String> pushed;

  setUpAll(() async {
    registerFallbackValue(const MoneyOverviewLoadRequested());
    await initializeDateFormatting('fr');
  });

  setUp(() {
    bloc = MockMoneyOverviewBloc();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    pushed = [];
  });

  void stub(MoneyOverviewState state) => whenListen(
    bloc,
    Stream<MoneyOverviewState>.value(state),
    initialState: const MoneyOverviewLoading(),
  );

  MoneyOverviewLoaded loaded(MoneyOverviewModel o) =>
      MoneyOverviewLoaded(o, now: kMoneyNow);

  Widget host({String? announcementId, ThemeData? theme}) {
    final location = announcementId == null
        ? kMoneyTripsRoute
        : '$kMoneyTripsRoute?announcementId=$announcementId';
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: kMoneyTripsRoute,
          builder: (_, s) {
            final id = s.uri.queryParameters['announcementId'];
            return MultiBlocProvider(
              providers: [
                BlocProvider<MoneyOverviewBloc>.value(value: bloc),
                BlocProvider(
                  create: (_) => MoneyTripsCubit(analytics, focusKey: id),
                ),
              ],
              child: MoneyTripsScreen(announcementId: id),
            );
          },
        ),
        GoRoute(
          path: '/bids/:bidId',
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Scaffold(body: Text('bid'));
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: theme ?? AppTheme.light(),
      locale: AppL10n.fr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  void tall(WidgetTester tester, {double width = 400}) {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('une carte par trajet, du plus proche au plus lointain, '
      'fermées par défaut, barre accessible', (tester) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Mes trajets'), findsOneWidget);
    expect(find.text('Du plus proche au plus lointain'), findsOneWidget);
    final abj = tester.getTopLeft(find.byKey(const Key('money-trip-abj'))).dy;
    final dkr = tester.getTopLeft(find.byKey(const Key('money-trip-dkr'))).dy;
    final bko = tester.getTopLeft(find.byKey(const Key('money-trip-bko'))).dy;
    expect(abj < dkr && dkr < bko, isTrue);

    expect(find.text('18 oct. · 6 colis'), findsOneWidget);
    expect(find.text('1 versé'), findsOneWidget);
    expect(find.text('1 livré'), findsOneWidget);
    expect(find.text('4 en séquestre'), findsOneWidget);
    expect(find.text('1 en litige'), findsOneWidget);
    expect(find.text('1 en vérification'), findsOneWidget);
    expect(find.text('1 en espèces'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Paris → Abidjan, 6 colis : 1 versé, 1 livré, 4 en séquestre'),
      ),
      findsOneWidget,
    );
    // Barre proportionnelle : 4 parts séquestre pour 1 versé.
    final escrow = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('money-trip-abj')),
        matching: find.byKey(const Key('money-bar-escrow')),
      ),
    );
    final paid = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('money-trip-abj')),
        matching: find.byKey(const Key('money-bar-paid')),
      ),
    );
    expect(escrow.width / paid.width, closeTo(4, 0.2));

    // Fermées : aucune ligne de colis.
    expect(find.byKey(const Key('money-line-abj-0')), findsNothing);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.moneyTripsViewed,
        properties: {'trip_count': 3, 'filtered': false},
      ),
    ).called(1);
  });

  testWidgets('dépli, tap sur un colis → /bids/:id, repli', (tester) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('money-trip-header-abj')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-line-abj-0')), findsOneWidget);
    expect(find.textContaining('DON-PAID'), findsOneWidget);
    expect(find.textContaining('versé le 6 oct.'), findsOneWidget);
    expect(find.textContaining('versement auto le 11 oct.'), findsOneWidget);
    expect(find.textContaining('Fatou S. · à la livraison'), findsWidgets);

    await tester.tap(find.byKey(const Key('money-line-abj-0')));
    await tester.pumpAndSettle();
    expect(pushed, ['/bids/abj-0']);
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(any(that: isA<MoneyOverviewRefreshRequested>())),
    ).called(1);

    await tester.tap(find.byKey(const Key('money-trip-header-abj')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-line-abj-0')), findsNothing);
  });

  testWidgets('espèces : commission réglée affichée côté voyageur', (
    tester,
  ) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host(announcementId: 'dkr'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('en espèces · commission réglée'),
      findsOneWidget,
    );
  });

  testWidgets('filtré sur un trajet : lui seul, déplié, lien vers tous', (
    tester,
  ) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host(announcementId: 'abj'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('money-trip-abj')), findsOneWidget);
    expect(find.byKey(const Key('money-trip-dkr')), findsNothing);
    expect(find.byKey(const Key('money-line-abj-0')), findsOneWidget);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.moneyTripsViewed,
        properties: {'trip_count': 3, 'filtered': true},
      ),
    ).called(1);

    await tester.tap(find.byKey(const Key('money-trips-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-trip-dkr')), findsOneWidget);
  });

  testWidgets('trajet ciblé introuvable : message et retour à la liste', (
    tester,
  ) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host(announcementId: 'gone'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-trip-not-found')), findsOneWidget);
    await tester.tap(find.text('Voir tous mes trajets'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-trip-abj')), findsOneWidget);
  });

  testWidgets('chargement progressif : 10 trajets puis 10 de plus', (
    tester,
  ) async {
    tall(tester);
    stub(loaded(manyTrips(14)));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-trip-t9')), findsOneWidget);
    expect(find.byKey(const Key('money-trip-t10')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('money-trips-more')),
      300,
    );
    await tester.tap(find.byKey(const Key('money-trips-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('money-trip-t13')),
      300,
    );
    expect(find.byKey(const Key('money-trip-t13')), findsOneWidget);
    expect(find.byKey(const Key('money-trips-more')), findsNothing);
  });

  testWidgets('vide et erreur', (tester) async {
    stub(loaded(const MoneyOverviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-trips-empty')), findsOneWidget);
  });

  testWidgets('erreur : « Réessayer »', (tester) async {
    stub(const MoneyOverviewError(OfflineException()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    verify(
      () => bloc.add(any(that: isA<MoneyOverviewLoadRequested>())),
    ).called(1);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('$width dp, thème sombre, carte dépliée : sans débordement', (
      tester,
    ) async {
      tall(tester, width: width);
      stub(loaded(richOverview()));
      await tester.pumpWidget(
        host(announcementId: 'dkr', theme: AppTheme.dark()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('money-line-dkr-xof')), findsOneWidget);
    });
  }
}
