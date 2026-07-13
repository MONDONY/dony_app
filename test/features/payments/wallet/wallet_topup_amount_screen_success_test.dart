import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

/// Widget test of the wallet top-up success flow — exercises the real
/// `DonyPaymentSheet.show(...).onSuccess` end to end (real `WalletBloc`,
/// mocked `WalletRepository`/`PaymentGateway`/`PaymentRepository`): the
/// SnackBar previously shown on success has been replaced by
/// `DonySuccessScreen`, and the CTA must still preserve the bool contract
/// the wallet screen relies on (`context.push<bool>(...)` → refresh only
/// when the popped value is `true`).
///
/// No PayPal button here — `WalletTopupAmountScreen` builds its
/// `PaymentSheetConfig` with `paymentMethodTypes: const []` (the backend
/// never declares PayPal on a wallet-recharge PaymentIntent) — so the
/// success path is driven via the "Nouvelle carte" + "Payer" flow instead
/// of the PayPal button used by other DonySuccessScreen migration tests.
///
/// `WalletBloc` is deliberately constructed INSIDE each `testWidgets` body
/// (not in `setUp`) — created in `setUp`, its internal event-transformer
/// subscription binds to the real zone instead of flutter_test's fake-async
/// pump zone, and `bloc.add(...)` events then never get drained by
/// `tester.pump()` (observed empirically: the same harness never progresses
/// past `WalletLoading` when the bloc is built in `setUp`).

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late _MockWalletRepository walletRepository;
  late MockAnalyticsBackend analyticsBackend;
  late _MockPaymentGateway paymentGateway;
  late _MockPaymentRepository paymentRepository;

  setUp(() {
    walletRepository = _MockWalletRepository();
    when(() => walletRepository.topupStripe(amount: any(named: 'amount')))
        .thenAnswer((_) async => 'pi_test_secret');

    analyticsBackend = MockAnalyticsBackend();

    paymentGateway = _MockPaymentGateway();
    // PlatformPayButton (Apple/Google Pay) plante hors iOS/Android réel —
    // on le désactive et paie via une nouvelle carte.
    when(() => paymentGateway.isPlatformPaySupported())
        .thenAnswer((_) async => false);
    when(() => paymentGateway.confirmWithNewCard(any()))
        .thenAnswer((_) async {});

    paymentRepository = _MockPaymentRepository();
    when(() => paymentRepository.listSavedPaymentMethods())
        .thenAnswer((_) async => []);

    if (getIt.isRegistered<PaymentGateway>()) {
      getIt.unregister<PaymentGateway>();
    }
    getIt.registerFactory<PaymentGateway>(() => paymentGateway);

    if (getIt.isRegistered<PaymentRepository>()) {
      getIt.unregister<PaymentRepository>();
    }
    getIt.registerFactory<PaymentRepository>(() => paymentRepository);

    // Consommé par `initState` (log de l'événement walletTopupStarted).
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(MockAnalyticsBackend()),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<PaymentGateway>()) {
      getIt.unregister<PaymentGateway>();
    }
    if (getIt.isRegistered<PaymentRepository>()) {
      getIt.unregister<PaymentRepository>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  bool? topupResult;

  Widget buildHarness(WalletBloc walletBloc) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => Scaffold(
            body: Builder(
              builder: (inner) => ElevatedButton(
                key: const Key('open'),
                onPressed: () async {
                  topupResult = await inner.push<bool>('/topup');
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/topup',
          builder: (_, __) => BlocProvider<WalletBloc>.value(
            value: walletBloc,
            child: const WalletTopupAmountScreen(paymentMethod: 'STRIPE'),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Accueil')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    );
  }

  /// Amène le harness jusqu'à la vue succès de la DonyPaymentSheet : ouvre
  /// l'écran, saisit 20 €, lance la recharge, choisit « Nouvelle carte » et
  /// paie. `pumpAndSettle` n'est pas utilisable une fois la sheet ouverte
  /// (bouton « Payer » en `isLoading` monté sous la sheet) — on enchaîne donc
  /// des pumps bornés pour vider les gaps async, comme dans les autres
  /// migrations DonySuccessScreen de cette branche.
  Future<void> _driveToPaymentSuccess(WidgetTester tester) async {
    final walletBloc = WalletBloc(
      walletRepository,
      makeEnabledAnalytics(analyticsBackend),
    );
    addTearDown(walletBloc.close);

    await tester.pumpWidget(buildHarness(walletBloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Recharger · Étape 2/2'), findsOneWidget);

    await tester.tap(find.text('20 €'));
    await tester.pump();

    await tester.tap(find.text('Recharger 20 € via Carte bancaire'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.byKey(const Key('paymentSheetNewCardTile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('paymentSheetNewCardTile')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('paymentSheetPayButton')));
    await tester.pump(); // PaymentSheetProcessing
    await tester.pump(); // PaymentSheetSuccess (résolution async du gateway)
    await tester
        .pump(const Duration(milliseconds: 900)); // déclenchement onSuccess
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets(
      'recharge réussie affiche DonySuccessScreen (plus de SnackBar)',
      (tester) async {
    await _driveToPaymentSuccess(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(
        find.text(
            'Recharge réussie — votre solde sera crédité dans un instant.'),
        findsNothing);

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Recharge réussie !'), findsOneWidget);
    expect(
        find.text('Ton solde sera crédité dans un instant.'), findsOneWidget);
    expect(find.text('Voir mon solde'), findsOneWidget);
  });

  testWidgets(
      'CTA de DonySuccessScreen ferme la recharge avec pop(true) — contrat '
      'bool intact pour wallet_screen', (tester) async {
    await _driveToPaymentSuccess(tester);
    expect(find.byType(DonySuccessScreen), findsOneWidget);

    await tester.tap(find.text('Voir mon solde'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // DonySuccessScreen ET l'écran de recharge sont fermés — retour à
    // l'écran hôte, avec `true` comme résultat du push<bool>.
    expect(find.byType(DonySuccessScreen), findsNothing);
    expect(find.byType(WalletTopupAmountScreen), findsNothing);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(topupResult, isTrue);
  });
}
