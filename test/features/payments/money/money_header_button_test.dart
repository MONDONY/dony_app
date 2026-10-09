import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_header_button.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'money_fixtures.dart';

class MockMoneyOverviewBloc
    extends MockBloc<MoneyOverviewEvent, MoneyOverviewState>
    implements MoneyOverviewBloc {}

void main() {
  late MockMoneyOverviewBloc bloc;
  late int opened;

  setUpAll(() => registerFallbackValue(const MoneyOverviewLoadRequested()));

  setUp(() {
    bloc = MockMoneyOverviewBloc();
    opened = 0;
  });

  Widget host({bool showAmount = true}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: BlocProvider<MoneyOverviewBloc>.value(
                value: bloc,
                child: MoneyHeaderButton(showAmount: showAmount),
              ),
            ),
          ),
        ),
        GoRoute(
          path: kMoneyOverviewRoute,
          builder: (_, _) {
            opened++;
            return const Scaffold(body: Text('money'));
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

  void stub(MoneyOverviewState s) => whenListen(
    bloc,
    const Stream<MoneyOverviewState>.empty(),
    initialState: s,
  );

  testWidgets('rien en attente : simple icône', (tester) async {
    stub(const MoneyOverviewLoaded(MoneyOverviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-header-amount')), findsNothing);
    expect(find.bySemanticsLabel('Mon argent'), findsOneWidget);
  });

  testWidgets('chargement ou erreur : simple icône', (tester) async {
    stub(const MoneyOverviewLoading());
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byKey(const Key('money-header-amount')), findsNothing);
  });

  testWidgets('argent à venir : pastille avec le montant', (tester) async {
    stub(MoneyOverviewLoaded(overviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final amount = tester.widget<Text>(
      find.byKey(const Key('money-header-amount')),
    );
    expect(amount.data, contains('17'));
    expect(
      find.bySemanticsLabel(RegExp(r'^Mon argent : .*17.* à venir$')),
      findsOneWidget,
    );
  });

  testWidgets('écran étroit : icône seule même avec de l\'argent à venir', (
    tester,
  ) async {
    stub(MoneyOverviewLoaded(overviewModel()));
    await tester.pumpWidget(host(showAmount: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('money-header-amount')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('à venir')), findsOneWidget);
  });

  testWidgets('tap → « Mon argent », rafraîchit au retour', (tester) async {
    stub(MoneyOverviewLoaded(overviewModel()));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('money-header-button')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(any(that: isA<MoneyOverviewRefreshRequested>())),
    ).called(1);
  });
}
