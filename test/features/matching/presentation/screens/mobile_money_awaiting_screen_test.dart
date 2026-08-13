import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/presentation/screens/mobile_money_awaiting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockBloc extends Mock implements MobileMoneyPaymentBloc {}

void main() {
  late _MockBloc bloc;

  setUpAll(() {
    // MobileMoneyPaymentEvent est sealed : le fallback est un vrai événement.
    registerFallbackValue(const MobileMoneyStatusPolled(bidId: 'bid-1'));
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(MockAnalyticsBackend()),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  void stub(MobileMoneyPaymentState state) {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<MobileMoneyPaymentState>.value(state));
  }

  /// [settle] reste faux tant qu'un CircularProgressIndicator tourne : son
  /// animation ne s'arrête jamais et ferait expirer pumpAndSettle.
  Future<void> pumpScreen(WidgetTester tester, {bool settle = true}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<MobileMoneyPaymentBloc>.value(
            value: bloc,
            child: const MobileMoneyAwaitingScreen(bidId: 'bid-1'),
          ),
        ),
        GoRoute(
          path: '/bids/:id',
          builder: (_, _) => const Scaffold(body: Text('Détail de l’envoi')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('état initial : indicateur de chargement', (tester) async {
    stub(const MobileMoneyPaymentInitial());

    await pumpScreen(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Paiement Mobile Money'), findsOneWidget);
  });

  testWidgets('ouverture : le statut est interrogé immédiatement', (
    tester,
  ) async {
    stub(const MobileMoneyPaymentInitial());

    await pumpScreen(tester, settle: false);

    // Ne pas attendre le premier tick de 10 s pour savoir où en est le paiement.
    verify(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>()))).called(1);
  });

  testWidgets('paiement en attente : lien et invite à payer', (tester) async {
    stub(
      const MobileMoneyPaymentPending(paymentLink: 'https://pay.example/abc'),
    );

    await pumpScreen(tester);

    expect(find.text('En attente de paiement'), findsOneWidget);
    expect(find.text('Cliquez sur le bouton pour payer'), findsOneWidget);
  });

  testWidgets('lien expiré : propose de le régénérer', (tester) async {
    stub(const MobileMoneyPaymentExpired());

    await pumpScreen(tester);

    expect(find.text('Lien expiré'), findsOneWidget);

    await tester.tap(find.text('Régénérer le lien'));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<MobileMoneyLinkRegenRequested>())),
    ).called(1);
  });

  testWidgets('erreur : message affiché et réessai possible', (tester) async {
    stub(const MobileMoneyPaymentError('Opérateur injoignable'));

    await pumpScreen(tester);

    expect(find.text('Opérateur injoignable'), findsOneWidget);

    // Le premier poll a déjà eu lieu à l'ouverture : le réessai en ajoute un.
    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>()))).called(2);
  });

  testWidgets('paiement confirmé : écran de confirmation puis redirection', (
    tester,
  ) async {
    stub(const MobileMoneyPaymentConfirmed());

    await pumpScreen(tester);

    expect(find.text('Détail de l’envoi'), findsOneWidget);
  });
}
