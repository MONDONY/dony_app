import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/screens/money_overview_screen.dart';
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

void main() {
  late MockMoneyOverviewBloc bloc;
  late List<String> pushed;

  setUpAll(() async {
    registerFallbackValue(const MoneyOverviewLoadRequested());
    await initializeDateFormatting('fr');
  });

  setUp(() {
    bloc = MockMoneyOverviewBloc();
    pushed = [];
  });

  void stub(MoneyOverviewState state) {
    whenListen(
      bloc,
      const Stream<MoneyOverviewState>.empty(),
      initialState: state,
    );
  }

  MoneyOverviewLoaded loaded(
    MoneyOverviewModel overview, {
    bool upcomingAvailable = true,
  }) => MoneyOverviewLoaded(
    overview,
    upcomingAvailable: upcomingAvailable,
    now: kMoneyNow,
  );

  Widget host({ThemeData? theme}) {
    Widget record(GoRouterState s, String label) {
      pushed.add(s.uri.toString());
      return Scaffold(body: Text(label));
    }

    final router = GoRouter(
      initialLocation: '/payments/money',
      routes: [
        GoRoute(
          path: '/payments/money',
          builder: (_, _) => BlocProvider<MoneyOverviewBloc>.value(
            value: bloc,
            child: const MoneyOverviewScreen(),
          ),
        ),
        GoRoute(path: kMoneyTripsRoute, builder: (_, s) => record(s, 'trips')),
        GoRoute(path: '/bids/:bidId', builder: (_, s) => record(s, 'bid')),
        GoRoute(
          path: '/payments/wallet',
          builder: (_, s) => record(s, 'wallet'),
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

  testWidgets('chargement', (tester) async {
    stub(const MoneyOverviewLoading());
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Mon argent'), findsOneWidget);
  });

  testWidgets('carte de tête : à venir et quatre tuiles, jamais le solde '
      'Yadony', (tester) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('À venir · 9 colis'), findsOneWidget);
    final card = find.byKey(const Key('money-upcoming-card'));
    expect(
      find.descendant(of: card, matching: find.textContaining('241')),
      findsOneWidget,
    );
    // L'autre devise en petit, jamais additionnée.
    expect(
      find.descendant(of: card, matching: find.textContaining('+ ')),
      findsOneWidget,
    );
    Finder tile(String name, String text) => find.descendant(
      of: find.byKey(Key('money-bucket-$name')),
      matching: find.textContaining(text),
    );
    expect(tile('thisWeek', 'Cette semaine'), findsOneWidget);
    expect(tile('thisWeek', '43'), findsOneWidget);
    expect(tile('nextWeek', '108'), findsOneWidget);
    expect(tile('later', '50'), findsOneWidget);
    expect(tile('later', '9'), findsWidgets); // 9 000 F CFA, ligne à part
    expect(tile('dispute', '40'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Semaine prochaine : 108')),
      findsOneWidget,
    );

    // Aucune trace du portefeuille Yadony dans les montants.
    expect(find.text('Disponible'), findsNothing);
    expect(find.textContaining('portefeuille'), findsNothing);
  });

  testWidgets('prochains versements : en cours, daté, trajets, litige, '
      'vérification', (tester) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Prochains versements'), findsOneWidget);
    expect(find.text('Livré · versement en cours'), findsOneWidget);
    expect(find.text('dim. 11 oct.'), findsOneWidget);
    expect(find.text('Arrivée 18 oct. · Paris → Abidjan'), findsOneWidget);
    expect(find.text('Arrivée 24 oct. · Lyon → Dakar'), findsOneWidget);
    expect(find.text('Bloqué · en litige'), findsOneWidget);
    expect(find.text('En vérification'), findsOneWidget);
    expect(
      find.text('3 colis versés à la confirmation de livraison'),
      findsOneWidget,
    );
    expect(
      find.text('2 colis versés à la confirmation de livraison'),
      findsOneWidget,
    );
    expect(find.text('Détail des 6 colis'), findsOneWidget);
    expect(find.text('Détail des 3 colis'), findsOneWidget);
    expect(
      find.textContaining('DON-5DD4 · Paris → Abidjan · versement auto'),
      findsOneWidget,
    );
    expect(
      find.textContaining('DON-4HJ8 · Marseille → Bamako · l\'équipe Yadony'),
      findsOneWidget,
    );

    // Groupe multi-devises : une ligne par devise, jamais additionnées.
    final dkr = find.byKey(const Key('money-group-trip-dkr'));
    expect(
      find.descendant(of: dkr, matching: find.textContaining('50')),
      findsWidgets,
    );
    expect(
      find.descendant(of: dkr, matching: find.textContaining('9')),
      findsWidgets,
    );
    expect(
      find.descendant(of: dkr, matching: find.textContaining('9 050')),
      findsNothing,
    );

    // Versés récemment, envois, lien discret vers le solde Yadony.
    expect(find.text('Versés récemment'), findsOneWidget);
    expect(find.textContaining('versé le 6 oct.'), findsOneWidget);
    expect(find.text('Mes envois'), findsOneWidget);
    expect(find.textContaining('DON-SENT'), findsOneWidget);
    expect(find.text('Mon solde Yadony'), findsOneWidget);
  });

  testWidgets('« Détail des N colis » ouvre Mes trajets filtré, puis '
      'rafraîchit au retour', (tester) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('money-trip-link-abj')));
    await tester.pumpAndSettle();
    expect(pushed, ['/payments/money/trips?announcementId=abj']);

    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(any(that: isA<MoneyOverviewRefreshRequested>())),
    ).called(1);
  });

  testWidgets('« Tous mes trajets », une ligne colis et le solde Yadony', (
    tester,
  ) async {
    tall(tester);
    stub(loaded(richOverview()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('money-all-trips')));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('money-line-auto')));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('money-wallet-link')));
    await tester.pumpAndSettle();
    expect(pushed, ['/payments/money/trips', '/bids/auto', '/payments/wallet']);
  });

  testWidgets('liste coupée par le back : note discrète', (tester) async {
    tall(tester);
    stub(loaded(richOverview(truncated: true)));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-truncated')), findsOneWidget);
  });

  testWidgets('expéditeur seul : argent payé en séquestre, sans tuiles', (
    tester,
  ) async {
    tall(tester);
    stub(
      loaded(
        MoneyOverviewModel(
          senderTotals: const [
            SenderTotalModel(
              currency: 'EUR',
              blocked: 60,
              refundPending: 0,
              refundedRecently: 0,
            ),
          ],
          senderItems: [
            item(bidId: 'sent', role: MoneyRole.sender, amount: 60),
            item(
              bidId: 'refunded',
              role: MoneyRole.sender,
              state: MoneyState.refundedRecently,
              settledAt: DateTime(2026, 10, 2),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Payé, en séquestre · 1 colis'), findsOneWidget);
    expect(find.byKey(const Key('money-bucket-thisWeek')), findsNothing);
    expect(find.textContaining('remboursé le 2 oct.'), findsOneWidget);
    expect(find.byKey(const Key('money-all-trips')), findsNothing);
  });

  testWidgets('vide : état « Rien en attente »', (tester) async {
    stub(loaded(const MoneyOverviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-empty')), findsOneWidget);
    expect(find.byKey(const Key('money-upcoming-card')), findsNothing);
  });

  testWidgets('ancien back : « Bientôt disponible », sans solde', (
    tester,
  ) async {
    stub(loaded(const MoneyOverviewModel(), upcomingAvailable: false));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('money-upcoming-card')), findsNothing);
  });

  testWidgets('erreur : message et « Réessayer » relance le chargement', (
    tester,
  ) async {
    stub(const MoneyOverviewError(OfflineException()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    verify(
      () => bloc.add(any(that: isA<MoneyOverviewLoadRequested>())),
    ).called(1);
  });

  testWidgets('pull-to-refresh envoie un rafraîchissement', (tester) async {
    stub(loaded(richOverview()));
    when(() => bloc.add(any())).thenAnswer((inv) {
      final e = inv.positionalArguments.first;
      if (e is MoneyOverviewRefreshRequested) e.completer?.complete();
    });
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(any(that: isA<MoneyOverviewRefreshRequested>())),
    ).called(1);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('$width dp, thème sombre : rendu sans débordement', (
      tester,
    ) async {
      tall(tester, width: width);
      stub(loaded(richOverview()));
      await tester.pumpWidget(host(theme: AppTheme.dark()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Prochains versements'), findsOneWidget);
    });
  }
}
