import 'package:bloc_test/bloc_test.dart';
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

  Widget host() {
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
        GoRoute(
          path: '/bids/:bidId',
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Scaffold(body: Text('bid'));
          },
        ),
        GoRoute(
          path: '/payments/wallet',
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Scaffold(body: Text('wallet'));
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

  testWidgets('chargement', (tester) async {
    stub(const MoneyOverviewLoading());
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Mon argent'), findsOneWidget);
  });

  testWidgets('séquestre affiché avec sa condition et sa date, frise '
      'accessible, multi-devises', (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    stub(MoneyOverviewLoaded(overviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Cartes de synthèse : solde EUR principal, XOF en second, séquestre XOF.
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Bloqué jusqu\'à livraison'), findsOneWidget);
    expect(find.text('2 colis en séquestre'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('money-available-card')),
        matching: find.textContaining('96,10'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('money-available-card')),
        matching: find.textContaining('+ '),
      ),
      findsOneWidget,
    );

    // Sections.
    expect(find.text('Quand mon argent arrive'), findsOneWidget);
    expect(find.text('Mes envois'), findsOneWidget);

    // Garde datée.
    expect(find.text('DON-5DD4K2QP · Paris → Abidjan'), findsOneWidget);
    expect(find.text('Awa K. · 10 kg'), findsOneWidget);
    expect(
      find.text('Versé automatiquement le 11 oct. si aucun litige'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Étape 3 sur 4, Livré'), findsOneWidget);

    // Séquestre avant remise : date de départ, condition de livraison.
    expect(find.text('Fatou S. · départ 18 oct.'), findsOneWidget);
    expect(
      find.text('Versé quand le destinataire confirme la livraison'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Étape 1 sur 4, Payé'), findsOneWidget);

    // Espèces : carte compacte, sans frise.
    expect(
      find.text('Payé en espèces à la remise · commission réglée'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('money-parcel-bid-cash')),
        matching: find.text('Payé'),
      ),
      findsNothing,
    );

    // Versé récemment, puis le litige côté expéditeur.
    expect(find.text('Versé le 5 oct.'), findsOneWidget);
    expect(find.text('En litige : l\'équipe Yadony décide'), findsOneWidget);
    expect(find.text('Moussa K. · 4,5 kg'), findsOneWidget);
    expect(
      find.byKey(const Key('money-timeline-segment-1-attention')),
      findsOneWidget,
    );
  });

  testWidgets('tap sur une carte → /bids/:id puis rafraîchissement', (
    tester,
  ) async {
    stub(MoneyOverviewLoaded(overviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('money-parcel-bid-held')));
    await tester.pumpAndSettle();
    expect(pushed, ['/bids/bid-held']);

    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.pop();
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(any(that: isA<MoneyOverviewRefreshRequested>())),
    ).called(1);
  });

  testWidgets('lien historique → écran du portefeuille', (tester) async {
    stub(const MoneyOverviewLoaded(MoneyOverviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('money-history-link')));
    await tester.pumpAndSettle();
    expect(pushed, ['/payments/wallet']);
  });

  testWidgets('vide : état « Rien en attente »', (tester) async {
    stub(
      const MoneyOverviewLoaded(
        MoneyOverviewModel(wallet: [MoneyAmount('EUR', 0)]),
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-empty')), findsOneWidget);
    expect(find.text('Rien en attente'), findsOneWidget);
    expect(find.text('Aucun colis en séquestre'), findsOneWidget);
  });

  testWidgets('ancien back : soldes seuls et « Bientôt disponible »', (
    tester,
  ) async {
    stub(
      const MoneyOverviewLoaded(
        MoneyOverviewModel(wallet: [MoneyAmount('EUR', 12.5)]),
        upcomingAvailable: false,
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-unavailable')), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsOneWidget);
    expect(find.byKey(const Key('money-blocked-card')), findsNothing);
    expect(find.textContaining('12,50'), findsOneWidget);
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
    stub(MoneyOverviewLoaded(overviewModel()));
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

  testWidgets('thème sombre : rendu sans erreur', (tester) async {
    stub(MoneyOverviewLoaded(overviewModel()));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<MoneyOverviewBloc>.value(
            value: bloc,
            child: const MoneyOverviewScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Quand mon argent arrive'), findsOneWidget);
  });
}
