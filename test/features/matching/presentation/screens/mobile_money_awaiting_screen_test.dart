import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
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

  const bidId = 'bid-1';

  const awaitingStatus = MobileMoneyPaymentStatus(
    bidId: bidId,
    bidStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 50.0,
    deposit: MobileMoneyDeposit(
      id: 'deposit-1',
      status: MobileMoneyDepositStatus.accepted,
      authorizationUrl: 'https://pay.example/abc',
    ),
  );

  const expiredStatus = MobileMoneyPaymentStatus(
    bidId: bidId,
    bidStatus: 'AWAITING_PAYMENT',
    amount: 50.0,
  );

  const depositFailedStatus = MobileMoneyPaymentStatus(
    bidId: bidId,
    bidStatus: 'AWAITING_PAYMENT',
    amount: 50.0,
    deposit: MobileMoneyDeposit(
      id: 'deposit-2',
      status: MobileMoneyDepositStatus.failed,
      failureMessage: 'Solde insuffisant',
    ),
  );

  const escrowedStatus = MobileMoneyPaymentStatus(
    bidId: bidId,
    bidStatus: 'ACCEPTED',
    paymentStatus: 'ESCROW',
    amount: 50.0,
  );

  setUpAll(() {
    // MobileMoneyPaymentEvent est sealed : le fallback est un vrai événement.
    registerFallbackValue(const MobileMoneyPaymentOpened(bidId: bidId));
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
            child: const MobileMoneyAwaitingScreen(bidId: bidId),
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

  testWidgets('ouverture : le statut est demandé immédiatement', (
    tester,
  ) async {
    stub(const MobileMoneyPaymentInitial());

    await pumpScreen(tester, settle: false);

    // Ne pas attendre le premier tick de 10 s pour savoir où en est le
    // paiement : l'ouverture de l'écran déclenche Opened, pas un simple
    // sondage (Opened peut initier un premier dépôt si aucun n'existe).
    verify(
      () => bloc.add(any(that: isA<MobileMoneyPaymentOpened>())),
    ).called(1);
  });

  testWidgets('paiement en attente : lien et invite à payer', (tester) async {
    stub(const MobileMoneyPaymentAwaitingConfirmation(awaitingStatus));

    await pumpScreen(tester);

    expect(find.text('En attente de paiement'), findsOneWidget);
    expect(find.text('Cliquez sur le bouton pour payer'), findsOneWidget);
  });

  testWidgets('lien expiré : propose de le régénérer', (tester) async {
    stub(const MobileMoneyPaymentExpired(expiredStatus));

    await pumpScreen(tester);

    expect(find.text('Lien expiré'), findsOneWidget);

    await tester.tap(find.text('Régénérer le lien'));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<MobileMoneyPaymentInitiateRequested>())),
    ).called(1);
  });

  testWidgets('dépôt refusé : message du backend affiché, réessai possible', (
    tester,
  ) async {
    stub(const MobileMoneyPaymentDepositFailed(depositFailedStatus));

    await pumpScreen(tester);

    expect(find.text('Solde insuffisant'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<MobileMoneyPaymentInitiateRequested>())),
    ).called(1);
  });

  testWidgets(
    'dépôt refusé sans message backend : repli sur "Paiement refusé"',
    (tester) async {
      stub(
        const MobileMoneyPaymentDepositFailed(
          MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'AWAITING_PAYMENT',
            amount: 50.0,
            deposit: MobileMoneyDeposit(
              id: 'deposit-3',
              status: MobileMoneyDepositStatus.submitRejected,
            ),
          ),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('Paiement refusé'), findsOneWidget);
    },
  );

  testWidgets(
    'erreur technique : message générique (jamais le détail brut), réessai '
    'relance l\'ouverture',
    (tester) async {
      stub(const MobileMoneyPaymentError(NetworkException('boom interne')));

      await pumpScreen(tester);

      // Jamais le détail technique brut affiché à l'utilisateur.
      expect(find.text('boom interne'), findsNothing);
      expect(find.text('Une erreur est survenue'), findsOneWidget);

      // Le premier Opened a déjà eu lieu à l'ouverture : le réessai en
      // ajoute un second, du même type (pas un simple Polled : il faut
      // pouvoir relancer l'initiation si nécessaire).
      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(
        () => bloc.add(any(that: isA<MobileMoneyPaymentOpened>())),
      ).called(2);
    },
  );

  testWidgets('paiement confirmé : écran de confirmation puis redirection', (
    tester,
  ) async {
    stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

    await pumpScreen(tester);

    expect(find.text('Détail de l’envoi'), findsOneWidget);
  });
}
