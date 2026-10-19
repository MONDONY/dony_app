import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/connect_onboarding/bloc/bank_account_link_cubit.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/bloc/money_trips_cubit.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/screens/money_overview_screen.dart';
import 'package:dony/features/payments/money/presentation/screens/money_trips_screen.dart';
import 'package:dony/features/payments/money/presentation/widgets/bank_payout_sheet.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import 'money_fixtures.dart';

class _MockMoneyOverviewBloc
    extends MockBloc<MoneyOverviewEvent, MoneyOverviewState>
    implements MoneyOverviewBloc {}

class _MockRepo extends Mock implements IConnectOnboardingRepository {}

BankPayoutModel _payout(
  BankPayoutStatus status, {
  DateTime? availableOn,
  DateTime? arrivalDate,
}) => BankPayoutModel(
  status: status,
  availableOn: availableOn,
  arrivalDate: arrivalDate,
);

MoneyItemModel _paid(BankPayoutModel? payout) => item(
  bidId: 'bid-paid',
  trackingNumber: 'DON-PAID0001',
  state: MoneyState.releasedRecently,
  settledAt: DateTime(2026, 10, 18),
  amount: 42,
  bankPayout: payout,
);

void main() {
  final l = AppLocalizationsFr();

  setUpAll(() async {
    registerFallbackValue(const MoneyOverviewLoadRequested());
    await initializeDateFormatting('fr');
  });

  group('bankPayoutSteps', () {
    List<BankPayoutStepState> states(BankPayoutStatus s) =>
        bankPayoutSteps(_paid(_payout(s)), l).map((e) => e.state).toList();

    const done = BankPayoutStepState.done;
    const current = BankPayoutStepState.current;
    const todo = BankPayoutStepState.todo;

    test('étape courante selon le statut', () {
      expect(states(BankPayoutStatus.pendingAvailability), [
        done,
        current,
        todo,
        todo,
      ]);
      expect(states(BankPayoutStatus.available), [done, done, current, todo]);
      expect(states(BankPayoutStatus.inTransit), [done, done, current, todo]);
      expect(states(BankPayoutStatus.paid), [done, done, done, done]);
      expect(states(BankPayoutStatus.failed), [
        done,
        done,
        BankPayoutStepState.failed,
        todo,
      ]);
      expect(states(BankPayoutStatus.unknown), [done, todo, todo, todo]);
    });

    test('libellés datés', () {
      final steps = bankPayoutSteps(
        _paid(
          _payout(
            BankPayoutStatus.inTransit,
            availableOn: DateTime(2026, 10, 22),
            arrivalDate: DateTime(2026, 10, 24),
          ),
        ),
        l,
      ).map((e) => e.label).toList();
      expect(steps, [
        'Payé sur votre compte Stripe le 18 oct.',
        'Disponible le 22 oct.',
        'Virement en cours, arrivée prévue le 24 oct.',
        'Arrivé sur votre banque',
      ]);
    });

    test('libellés sans date, payé, échoué', () {
      final noDate = item(
        state: MoneyState.releasedRecently,
        bankPayout: _payout(BankPayoutStatus.available),
      );
      expect(bankPayoutSteps(noDate, l).map((e) => e.label), [
        'Payé sur votre compte Stripe',
        'Disponible sur votre compte Stripe',
        'Virement vers votre banque',
        'Arrivé sur votre banque',
      ]);
      final paid = bankPayoutSteps(
        _paid(
          _payout(BankPayoutStatus.paid, arrivalDate: DateTime(2026, 10, 24)),
        ),
        l,
      );
      expect(paid[2].label, 'Virement envoyé par Stripe');
      expect(paid[3].label, 'Arrivé sur votre banque le 24 oct.');
      expect(
        bankPayoutSteps(_paid(_payout(BankPayoutStatus.failed)), l)[2].label,
        'Virement échoué',
      );
    });
  });

  group('feuille depuis « Mon argent »', () {
    late _MockMoneyOverviewBloc bloc;
    late _MockRepo repo;
    late List<String> pushed;

    setUp(() {
      bloc = _MockMoneyOverviewBloc();
      repo = _MockRepo();
      pushed = [];
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      if (getIt.isRegistered<BankAccountLinkCubit>()) {
        getIt.unregister<BankAccountLinkCubit>();
      }
      getIt.registerFactory<BankAccountLinkCubit>(
        () => BankAccountLinkCubit(repo, analytics),
      );
    });

    tearDown(() {
      if (getIt.isRegistered<BankAccountLinkCubit>()) {
        getIt.unregister<BankAccountLinkCubit>();
      }
    });

    Widget host(MoneyItemModel paidItem, {String start = '/payments/money'}) {
      whenListen(
        bloc,
        const Stream<MoneyOverviewState>.empty(),
        initialState: MoneyOverviewLoaded(
          MoneyOverviewModel(travelerItems: [paidItem]),
          now: kMoneyNow,
        ),
      );
      Widget record(GoRouterState s, String label) {
        pushed.add(s.uri.toString());
        return Scaffold(body: Text(label));
      }

      final router = GoRouter(
        initialLocation: start,
        routes: [
          GoRoute(
            path: '/payments/money',
            builder: (_, _) => BlocProvider<MoneyOverviewBloc>.value(
              value: bloc,
              child: const MoneyOverviewScreen(),
            ),
          ),
          GoRoute(
            path: kMoneyTripsRoute,
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider<MoneyOverviewBloc>.value(value: bloc),
                BlocProvider(
                  create: (_) => MoneyTripsCubit(
                    makeEnabledAnalytics(MockAnalyticsBackend()),
                    focusKey: 'ann-1',
                  ),
                ),
              ],
              child: const MoneyTripsScreen(announcementId: 'ann-1'),
            ),
          ),
          GoRoute(path: '/bids/:bidId', builder: (_, s) => record(s, 'bid')),
          GoRoute(
            path: '/payments/onboarding',
            builder: (_, s) => record(s, 'payouts'),
          ),
          GoRoute(
            path: '/payments/wallet',
            builder: (_, s) => record(s, 'wallet'),
          ),
        ],
      );
      return MaterialApp.router(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      );
    }

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('ligne : état court, tap ouvre la frise, « Voir le colis »', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        host(
          _paid(
            _payout(
              BankPayoutStatus.pendingAvailability,
              availableOn: DateTime(2026, 10, 22),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payés récemment'), findsOneWidget);
      expect(find.textContaining('payé, dispo le 22 oct.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('money-line-bid-paid')));
      await tester.pumpAndSettle();

      expect(find.text('Suivi du virement'), findsOneWidget);
      expect(find.byKey(const Key('bank-payout-timeline')), findsOneWidget);
      expect(
        find.text('Payé sur votre compte Stripe le 18 oct.'),
        findsOneWidget,
      );
      expect(find.text('Disponible le 22 oct.'), findsOneWidget);
      expect(find.byKey(const Key('bank-step-current')), findsOneWidget);
      expect(find.textContaining('1 à 3 jours ouvrés'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Disponible le 22 oct., en cours'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('change-bank-account')), findsNothing);
      expect(pushed, isEmpty);

      await tester.tap(find.byKey(const Key('bank-payout-open-parcel')));
      await tester.pumpAndSettle();
      expect(pushed, ['/bids/bid-paid']);
      expect(find.text('bid'), findsOneWidget);
    });

    testWidgets('payé : toutes les étapes terminées', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        host(
          _paid(
            _payout(BankPayoutStatus.paid, arrivalDate: DateTime(2026, 10, 24)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('arrivé sur votre banque le 24 oct.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('money-line-bid-paid')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bank-step-done')), findsNWidgets(4));
      expect(find.text('Arrivé sur votre banque le 24 oct.'), findsOneWidget);
    });

    testWidgets('échoué : aide dédiée et « Changer de compte bancaire », '
        '409 renvoie vers l\'inscription Stripe', (tester) async {
      tall(tester);
      when(repo.createDashboardLink).thenThrow(
        const ConflictException('x', code: 'stripe-onboarding-incomplete'),
      );
      await tester.pumpWidget(host(_paid(_payout(BankPayoutStatus.failed))));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('virement échoué, vérifiez votre banque'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('money-line-bid-paid')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bank-step-failed')), findsOneWidget);
      expect(find.textContaining('refusé le virement'), findsOneWidget);
      expect(find.text('Changer de compte bancaire'), findsOneWidget);

      await tester.tap(find.byKey(const Key('change-bank-account')));
      await tester.pumpAndSettle();
      expect(pushed, ['/payments/onboarding']);
      expect(find.text('Suivi du virement'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sans suivi bancaire : le tap ouvre directement le colis', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(host(_paid(null)));
      await tester.pumpAndSettle();
      expect(find.textContaining('versé le 18 oct.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('money-line-bid-paid')));
      await tester.pumpAndSettle();
      expect(pushed, ['/bids/bid-paid']);
      expect(find.text('Suivi du virement'), findsNothing);
    });

    testWidgets('« Mes trajets » : même feuille au tap', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        host(
          _paid(_payout(BankPayoutStatus.available)),
          start: '$kMoneyTripsRoute?announcementId=ann-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('virement bancaire à venir'), findsOneWidget);
      await tester.tap(find.byKey(const Key('money-line-bid-paid')));
      await tester.pumpAndSettle();
      expect(find.text('Suivi du virement'), findsOneWidget);
    });
  });
}
