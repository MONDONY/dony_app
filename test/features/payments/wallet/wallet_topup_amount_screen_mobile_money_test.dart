import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';

/// Écran de montant, branche mobile money : devise de l'opérateur sans
/// centimes, aucune borne min/max devinée (A5 — le back n'en expose
/// aucune), initiation puis navigation vers l'écran d'attente en
/// remplaçant cet écran dans la pile.
class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository repo;
  late MockAnalyticsBackend analyticsBackend;
  late WalletTopupMobileMoneyCubit cubit;
  WalletTopupMobileMoneyAwaitingArgs? capturedArgs;

  const topup = WalletTopupModel(
    topupId: 'topup-1',
    currency: 'XOF',
    provider: 'ORANGE_SEN',
    providerLabel: 'Orange Money',
    msisdnMasked: '+221 ** ** 12 34',
  );

  setUp(() {
    repo = _MockWalletRepository();
    analyticsBackend = MockAnalyticsBackend();
    cubit = WalletTopupMobileMoneyCubit(
      repo,
      makeEnabledAnalytics(analyticsBackend),
    );
    capturedArgs = null;
    when(
      () => repo.topupMobileMoney(
        amount: any(named: 'amount'),
        phoneNumber: any(named: 'phoneNumber'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer((_) async => topup);
    // Jamais réellement invoqué dans ces tests (le sondage réel est annulé
    // avant que ses 3 s ne s'écoulent) — stub défensif au cas où.
    when(() => repo.topupStatus(any())).thenAnswer(
      (_) async => const WalletTopupStatusModel(
        topupId: 'topup-1',
        status: 'PENDING',
        amount: 5000,
        currency: 'XOF',
        provider: 'ORANGE_SEN',
        providerLabel: 'Orange Money',
        msisdnMasked: '+221 ** ** 12 34',
      ),
    );

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(MockAnalyticsBackend()),
    );
  });

  tearDown(() {
    unawaited(cubit.close());
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/amount',
      routes: [
        GoRoute(
          path: '/payments/wallet/topup/amount',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>.value(
                value: cubit,
                child: const WalletTopupAmountScreen(
                  paymentMethod: 'MOBILE_MONEY',
                  mobileMoneyPhoneNumber: '+221771234567',
                  mobileMoneyCurrency: 'XOF',
                ),
              ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/mobile-money/awaiting',
          builder: (context, state) {
            capturedArgs = state.extra as WalletTopupMobileMoneyAwaitingArgs;
            return const Scaffold(body: Text('Attente'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  /// Tape un raccourci de montant rapide (1000/2000/5000/10000 en F CFA).
  Future<void> tapQuickAmount(WidgetTester tester, int amount) async {
    final finder = find.text('$amount F CFA');
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets(
    'devise de l\'opérateur (XOF) sans décimales, pas de bouton décimal',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.text('Recharger · Étape 2/2'), findsOneWidget);

      await tapQuickAmount(tester, 5000);

      expect(find.textContaining('F CFA'), findsWidgets);
      // « Autre montant » : clavier numérique sans virgule décimale.
      await tester.ensureVisible(find.text('Autre montant'));
      await tester.tap(find.text('Autre montant'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('wallet-topup-custom-amount-field')),
      );
      expect(field.keyboardType, const TextInputType.numberWithOptions());
      // Bandeau dédié au F CFA sans centimes.
      expect(
        find.textContaining('Le F CFA ne connaît pas les centimes'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'bouton désactivé à zéro, actif dès un montant positif (aucune borne min/max devinée)',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.text('Entrez un montant'), findsOneWidget);

      await tapQuickAmount(tester, 1000);

      // 1000 F CFA (≈ 1,50 €) reste actif : aucune borne devinée côté
      // client, contrairement à Stripe (minimum 5 € codé en dur).
      expect(find.text('Payer 1000 F CFA'), findsOneWidget);
    },
  );

  testWidgets(
    'Payer déclenche initiate() puis remplace l\'écran par celui d\'attente '
    'avec la même instance de cubit',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tapQuickAmount(tester, 10000);

      final payButton = find.text('Payer 10000 F CFA');
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      verify(
        () =>
            repo.topupMobileMoney(amount: 10000, phoneNumber: '+221771234567'),
      ).called(1);

      expect(find.text('Attente'), findsOneWidget);
      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.cubit, same(cubit));
      expect(capturedArgs!.phoneNumber, '+221771234567');
      expect(capturedArgs!.amount, 10000);
      // L'écran de montant a bien été remplacé (pushReplacement), pas
      // simplement empilé par-dessus.
      expect(find.text('Recharger · Étape 2/2'), findsNothing);

      // initiate() a démarré le sondage périodique (3 s réelles) : l'arrêter
      // explicitement ici, sinon le timer reste "pending" à la fin du test
      // (tearDown ferme le cubit trop tard pour la vérification du binding).
      cubit.stopPolling();
    },
  );

  group('« Autre montant » (FLUTTER-CF)', () {
    Future<void> openCustom(WidgetTester tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      final chip = find.byKey(const Key('wallet-topup-custom-amount-chip'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    Finder field() => find.byKey(const Key('wallet-topup-custom-amount-field'));

    testWidgets('les montants proposés restent, le champ libre est absent '
        'tant que « Autre montant » n\'est pas choisi', (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      for (final a in const [1000, 2000, 5000, 10000]) {
        expect(find.text('$a F CFA'), findsOneWidget);
      }
      expect(find.text('Autre montant'), findsOneWidget);
      expect(field(), findsNothing);
    });

    testWidgets('champ libre : unité en suffixe, montant saisi payé et '
        'marqué « custom » côté analytics', (tester) async {
      await openCustom(tester);

      expect(field(), findsOneWidget);
      final decoration = tester.widget<TextField>(field()).decoration!;
      expect(decoration.suffixText, 'F CFA');
      expect(decoration.labelText, 'Montant à recharger');
      // Le choix d'« Autre montant » repart d'un montant vide.
      expect(find.text('Entrez un montant'), findsOneWidget);

      await tester.enterText(field(), '12500');
      await tester.pump();

      final pay = find.text('Payer 12500 F CFA');
      expect(pay, findsOneWidget);
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();

      verify(
        () =>
            repo.topupMobileMoney(amount: 12500, phoneNumber: '+221771234567'),
      ).called(1);
      expect(capturedArgs!.amount, 12500);
      cubit.stopPolling();
    });

    testWidgets('F CFA : ni centimes ni lettres dans le champ', (tester) async {
      await openCustom(tester);

      await tester.enterText(field(), '1500,5');
      await tester.pump();
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);

      await tester.enterText(field(), '1500');
      await tester.pump();
      await tester.enterText(field(), '1500a');
      await tester.pump();
      expect(tester.widget<TextField>(field()).controller!.text, '1500');
    });

    testWidgets('montant nul : erreur à la perte de focus, bouton désactivé', (
      tester,
    ) async {
      await openCustom(tester);

      await tester.enterText(field(), '0');
      await tester.pump();
      // Pas d'erreur pendant la frappe.
      expect(find.text('Indique un montant supérieur à 0.'), findsNothing);

      // « OK » du clavier : le champ perd le focus.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Indique un montant supérieur à 0.'), findsOneWidget);
      expect(find.text('Entrez un montant'), findsOneWidget);
    });

    testWidgets('revenir à un montant proposé referme le champ libre', (
      tester,
    ) async {
      await openCustom(tester);
      await tester.enterText(field(), '7777');
      await tester.pump();

      await tapQuickAmount(tester, 2000);
      await tester.pumpAndSettle();

      expect(field(), findsNothing);
      expect(find.text('Payer 2000 F CFA'), findsOneWidget);
    });

    testWidgets('anglais : « Other amount »', (tester) async {
      useEnglish();
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      expect(find.text('Other amount'), findsOneWidget);
    });
  });

  testWidgets('anglais : montant sans décimales et bouton Pay traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Top up · Step 2/2'), findsOneWidget);
    expect(find.text('Enter an amount'), findsOneWidget);

    await tapQuickAmount(tester, 1000);

    expect(find.text('Pay 1000 F CFA'), findsOneWidget);
    expect(find.textContaining("doesn't use cents"), findsOneWidget);
  });

  group('devise de l\'opérateur différente de la devise active', () {
    /// Enregistre le dépôt wallet dans GetIt : c'est lui que l'écran
    /// interroge pour connaître la devise réelle du portefeuille.
    void registerWallet(String currency) {
      if (getIt.isRegistered<WalletRepository>()) {
        getIt.unregister<WalletRepository>();
      }
      when(() => repo.getBalance()).thenAnswer(
        (_) async =>
            WalletModel(balance: 0, currency: currency, transactions: const []),
      );
      getIt.registerSingleton<WalletRepository>(repo);
      addTearDown(() {
        if (getIt.isRegistered<WalletRepository>()) {
          getIt.unregister<WalletRepository>();
        }
      });
    }

    testWidgets(
      'IMPORTANT — portefeuille en EUR, opérateur en XOF : avertissement '
      'avant de payer (le solde arriverait verrouillé)',
      (tester) async {
        registerWallet('EUR');

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('wallet-topup-currency-mismatch')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Ton portefeuille Franc CFA Ouest sera crédité du montant que tu saisis',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('crédité de 0'), findsNothing);
        expect(
          find.textContaining('Ton portefeuille Euro ne bouge pas'),
          findsOneWidget,
        );
        expect(find.textContaining('verrouillé'), findsNothing);
      },
    );

    testWidgets('portefeuille déjà en XOF : aucun avertissement', (
      tester,
    ) async {
      registerWallet('XOF');

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wallet-topup-currency-mismatch')),
        findsNothing,
      );
    });

    testWidgets('le bandeau de destination suit le montant saisi', (
      tester,
    ) async {
      registerWallet('EUR');

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      await tapQuickAmount(tester, 5000);

      final formatted = CurrencyFormatter.format(
        5000,
        SupportedCurrency.fromCodeOrDefault('XOF'),
      );
      expect(find.textContaining('sera crédité de $formatted'), findsOneWidget);
    });
  });
}
