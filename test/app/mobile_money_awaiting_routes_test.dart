import 'dart:async';

import 'package:dony/app/router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/presentation/screens/mobile_money_awaiting_screen.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_analytics_backend.dart';
import '../helpers/payer_account_test_doubles.dart';

class _MockBloc extends Mock implements MobileMoneyPaymentBloc {}

/// Câblage des trois routes « Payer le colis » (bid, négociation, supplément) :
/// chacune fournit à l'écran son `MobileMoneyPaymentBloc` ET le
/// `PayerAccountCubit` (créé avec le nom analytics de la portée). Un
/// fournisseur manquant ne se verrait qu'à l'exécution (`ProviderNotFound`),
/// jamais dans les tests de l'écran, qui fournissent leurs propres doublures.
void main() {
  late _MockBloc bloc;
  late MockPayerAccountCubit payerCubit;
  late List<String> payerFlows;
  late int blocCreations;

  const choosing = MobileMoneyPaymentChoosePayer(
    status: MobileMoneyPaymentStatus(subjectId: 'x', amount: 12500),
  );

  setUpAll(() {
    registerFallbackValue(
      const MobileMoneyPaymentOpened(scope: MobileMoneyScope.bid('x')),
    );
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
    when(() => bloc.canResend).thenReturn(false);
    // Déjà à l'étape « Qui paie ? » : le composant est lu dès l'ouverture.
    when(() => bloc.state).thenReturn(choosing);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<MobileMoneyPaymentState>.empty());

    payerCubit = MockPayerAccountCubit();
    final controller = stubPayerAccount(payerCubit, kPayerReady);
    addTearDown(controller.close);
    when(
      () => payerCubit.configure(
        currency: any(named: 'currency'),
        allowedOperators: any(named: 'allowedOperators'),
      ),
    ).thenAnswer((_) async {});

    payerFlows = [];
    blocCreations = 0;
    getIt.registerFactory<MobileMoneyPaymentBloc>(() {
      blocCreations++;
      return bloc;
    });
    getIt.registerFactoryParam<PayerAccountCubit, String, void>((flow, _) {
      payerFlows.add(flow);
      return payerCubit;
    });
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(MockAnalyticsBackend())..onConfigured(),
    );
  });

  tearDown(() {
    getIt.unregister<MobileMoneyPaymentBloc>();
    getIt.unregister<PayerAccountCubit>();
    getIt.unregister<AnalyticsService>();
  });

  Future<void> open(
    WidgetTester tester,
    String location, {
    Object? extra,
  }) async {
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (_, _) => const Scaffold(body: Text('host')),
        ),
        ...buildMobileMoneyAwaitingRoutes(),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    unawaited(
      tester.element(find.text('host')).push<bool>(location, extra: extra),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Minuterie à zéro seconde des apparitions animées du composant.
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 400));
  }

  BuildContext screenContext(WidgetTester tester) =>
      tester.element(find.byType(MobileMoneyAwaitingScreen));

  final cases = <({String name, String location, MobileMoneyScope scope})>[
    (
      name: 'bid',
      location: '/bids/bid-1/mobile-money/awaiting',
      scope: const MobileMoneyScope.bid('bid-1'),
    ),
    (
      name: 'negotiation',
      location: '/negotiations/thread-1/mobile-money/awaiting',
      scope: const MobileMoneyScope.negotiation('thread-1'),
    ),
    (
      name: 'bid_supplement',
      location: '/bids/bid-1/supplements/sup-1/mobile-money/awaiting',
      scope: const MobileMoneyScope.supplement(
        bidId: 'bid-1',
        supplementId: 'sup-1',
      ),
    ),
  ];

  for (final c in cases) {
    testWidgets('route_${c.name}_providesBlocAndPayerAccountCubit', (
      tester,
    ) async {
      await open(tester, c.location);

      expect(tester.takeException(), isNull);
      final screen = tester.widget<MobileMoneyAwaitingScreen>(
        find.byType(MobileMoneyAwaitingScreen),
      );
      expect(screen.scope, c.scope);
      // Les deux fournisseurs se résolvent depuis l'écran.
      expect(screenContext(tester).read<MobileMoneyPaymentBloc>(), same(bloc));
      expect(screenContext(tester).read<PayerAccountCubit>(), same(payerCubit));
      expect(blocCreations, 1);
      // Le composant porte le nom analytics de la portée.
      expect(payerFlows, [c.name]);
      // L'écran ouvre le paiement et rend le composant « compte qui paie ».
      verify(
        () => bloc.add(MobileMoneyPaymentOpened(scope: c.scope)),
      ).called(1);
      expect(find.text('COMPTE QUI PAIE'), findsOneWidget);
    });
  }

  testWidgets('route_negotiation_strayStringExtraIsIgnored', (tester) async {
    await open(
      tester,
      '/negotiations/thread-1/mobile-money/awaiting',
      extra: '+221771234567',
    );

    // Un ancien appelant qui poserait encore un `extra` ne casse rien : la
    // route ne le lit pas, le payeur se choisit sur l'écran.
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<MobileMoneyAwaitingScreen>(
            find.byType(MobileMoneyAwaitingScreen),
          )
          .scope,
      const MobileMoneyScope.negotiation('thread-1'),
    );
  });
}
