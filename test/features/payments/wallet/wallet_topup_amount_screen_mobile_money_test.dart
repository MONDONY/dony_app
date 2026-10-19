import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
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

/// Écran de montant, branche mobile money : compte qui paie rappelé en haut,
/// montant libre dans la carte, bornes réelles de l'opérateur, une seule
/// ligne sur le portefeuille crédité, initiation puis navigation vers
/// l'écran d'attente en remplaçant cet écran dans la pile.
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

  setUp(() async {
    repo = _MockWalletRepository();
    analyticsBackend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(analyticsBackend);
    // Service configuré : les événements du cubit atteignent le backend.
    await analytics.onConfigured();
    cubit = WalletTopupMobileMoneyCubit(repo, analytics);
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

  /// Orange Money Côte d'Ivoire, bornes pawaPay 100 à 1 500 000 F CFA.
  const orangeCiv = MobileMoneyOperator(
    code: 'ORANGE_CIV',
    label: 'Orange Money',
    brand: 'ORANGE',
    minAmount: 100,
    maxAmount: 1500000,
  );

  Widget buildHarness({MobileMoneyOperator? operator = orangeCiv}) {
    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/amount',
      routes: [
        GoRoute(
          path: '/payments/wallet/topup/amount',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>.value(
                value: cubit,
                child: WalletTopupAmountScreen(
                  paymentMethod: 'MOBILE_MONEY',
                  mobileMoneyPhoneNumber: '+2250748840856',
                  mobileMoneyCurrency: 'XOF',
                  mobileMoneyOperator: operator,
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

  Finder field() => find.byKey(const Key('wallet-topup-custom-amount-field'));

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller!.text;

  DonyButton payButton(WidgetTester tester) =>
      tester.widget<DonyButton>(find.byType(DonyButton));

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

  testWidgets('amountScreen_showsFromAccountRow_andSingleCreditLine', (
    tester,
  ) async {
    registerWallet('XOF');
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Recharger · Étape 2/2'), findsOneWidget);
    expect(find.text('Depuis Orange Money ••56'), findsOneWidget);
    expect(find.text('Changer'), findsOneWidget);
    expect(
      find.text('Crédité sur votre portefeuille Franc CFA Ouest'),
      findsOneWidget,
    );
    // Les anciens bandeaux sur la devise ont disparu.
    expect(find.textContaining('ne connaît pas les centimes'), findsNothing);
    expect(
      find.byKey(const Key('wallet-topup-currency-mismatch')),
      findsNothing,
    );
    expect(find.textContaining('ne bouge pas'), findsNothing);
  });

  testWidgets('ancien parcours : opérateur coché dans le catalogue du cubit', (
    tester,
  ) async {
    when(() => repo.topupProviders(any())).thenAnswer(
      (_) async => const MobileMoneyProviderCatalog(
        country: 'SN',
        currency: 'XOF',
        msisdnMasked: '+221 ** ** 12 34',
        detected: 'WAVE_SEN',
        providers: [
          MobileMoneyProviderOption(code: 'ORANGE_SEN', label: 'Orange Money'),
          MobileMoneyProviderOption(
            code: 'WAVE_SEN',
            label: 'Wave',
            detected: true,
          ),
        ],
      ),
    );
    await cubit.loadProviders('+2250748840856');

    await tester.pumpWidget(buildHarness(operator: null));
    await tester.pumpAndSettle();

    expect(find.text('Depuis Wave ••56'), findsOneWidget);
    // Sans catalogue des pays, aucune borne connue.
    await tester.enterText(field(), '50');
    await tester.pump();
    expect(find.textContaining('Entre '), findsNothing);
  });

  testWidgets(
    'ancien parcours sans opérateur choisi : pas de ligne « Depuis »',
    (tester) async {
      await tester.pumpWidget(buildHarness(operator: null));
      await tester.pumpAndSettle();

      expect(find.textContaining('Depuis'), findsNothing);
      expect(find.text('Changer'), findsNothing);
    },
  );

  testWidgets(
    'amountScreen_currencyDiffersFromActive_appendsUnchangedSentence',
    (tester) async {
      registerWallet('EUR');
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      // Même ligne : la destination, puis le portefeuille actif inchangé.
      expect(
        find.text(
          'Crédité sur votre portefeuille Franc CFA Ouest. '
          'Votre portefeuille Euro ne bouge pas.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('« Changer » revient au choix du compte qui paie', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/method',
      routes: [
        GoRoute(
          path: '/method',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/payments/wallet/topup/amount'),
              child: const Text('Écran 1'),
            ),
          ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/amount',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>.value(
                value: cubit,
                child: const WalletTopupAmountScreen(
                  paymentMethod: 'MOBILE_MONEY',
                  mobileMoneyPhoneNumber: '+2250748840856',
                  mobileMoneyCurrency: 'XOF',
                  mobileMoneyOperator: orangeCiv,
                ),
              ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Écran 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Changer'));
    await tester.pumpAndSettle();

    expect(find.text('Écran 1'), findsOneWidget);
  });

  testWidgets('quickAmount_fillsField', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Entrez un montant'), findsOneWidget);

    await tapQuickAmount(tester, 5000);

    expect(fieldText(tester), '5 000');
    expect(find.text('Payer 5000 F CFA'), findsOneWidget);
    // Montant rapide : la ligne du portefeuille crédité reste affichée.
    expect(
      find.textContaining('Crédité sur votre portefeuille'),
      findsOneWidget,
    );
  });

  testWidgets('customAmount_outOfBounds_disablesPay_andShowsBounds', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autre montant'));
    await tester.pumpAndSettle();

    final currency = SupportedCurrency.fromCodeOrDefault('XOF');
    final bounds =
        'Entre ${CurrencyFormatter.formatAmountOnly(100, currency)} et '
        '${CurrencyFormatter.format(1500000, currency)}';
    expect(find.text(bounds), findsOneWidget);

    await tester.enterText(field(), '50');
    await tester.pump();
    expect(find.text(bounds), findsOneWidget);
    expect(payButton(tester).onPressed, isNull);

    await tester.enterText(field(), '2000000');
    await tester.pump();
    expect(payButton(tester).onPressed, isNull);

    await tester.enterText(field(), '7500');
    await tester.pump();
    expect(find.text('Payer 7500 F CFA'), findsOneWidget);
    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets('sans bornes publiées : aucun plafond deviné', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        operator: const MobileMoneyOperator(
          code: 'ORANGE_CIV',
          label: 'Orange Money',
          brand: 'ORANGE',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(field(), '50');
    await tester.pump();

    expect(find.textContaining('Entre '), findsNothing);
    expect(find.text('Payer 50 F CFA'), findsOneWidget);
    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'Payer déclenche initiate() puis remplace l\'écran par celui d\'attente '
    'avec la même instance de cubit',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tapQuickAmount(tester, 10000);

      final pay = find.text('Payer 10000 F CFA');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();

      verify(
        () =>
            repo.topupMobileMoney(amount: 10000, phoneNumber: '+2250748840856'),
      ).called(1);

      expect(find.text('Attente'), findsOneWidget);
      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.cubit, same(cubit));
      expect(capturedArgs!.phoneNumber, '+2250748840856');
      expect(capturedArgs!.amount, 10000);
      // L'écran de montant a bien été remplacé (pushReplacement), pas
      // simplement empilé par-dessus.
      expect(find.text('Recharger · Étape 2/2'), findsNothing);

      // initiate() a démarré le sondage périodique (3 s réelles) : l'arrêter
      // explicitement ici, sinon le timer reste "pending" à la fin du test.
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

    testWidgets('montants proposés et « Autre montant » côte à côte', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      for (final a in const [1000, 2000, 5000, 10000]) {
        expect(find.text('$a F CFA'), findsOneWidget);
      }
      expect(find.text('Autre montant'), findsOneWidget);
    });

    testWidgets(
      'montant saisi au clavier : groupé, payé et marqué « custom »',
      (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        await tapQuickAmount(tester, 5000);

        // « Autre montant » repart d'un montant vide, clavier numérique.
        await tester.tap(
          find.byKey(const Key('wallet-topup-custom-amount-chip')),
        );
        await tester.pumpAndSettle();
        expect(fieldText(tester), isEmpty);
        expect(find.text('Entrez un montant'), findsOneWidget);
        expect(
          tester.widget<TextField>(field()).keyboardType,
          const TextInputType.numberWithOptions(),
        );

        await tester.enterText(field(), '12500');
        await tester.pump();
        expect(fieldText(tester), '12 500');

        final pay = find.text('Payer 12500 F CFA');
        expect(pay, findsOneWidget);
        await tester.ensureVisible(pay);
        await tester.tap(pay);
        await tester.pumpAndSettle();

        verify(
          () => repo.topupMobileMoney(
            amount: 12500,
            phoneNumber: '+2250748840856',
          ),
        ).called(1);
        expect(capturedArgs!.amount, 12500);
        // Montant saisi au clavier : marqué « custom », jamais le montant.
        final props =
            verify(
                  () => analyticsBackend.capture(
                    'wallet_topup_mobile_money_initiated',
                    captureAny(),
                  ),
                ).captured.single
                as Map<String, Object>?;
        expect(props?['custom'], isTrue);
        cubit.stopPolling();
      },
    );

    testWidgets('F CFA : ni centimes ni lettres dans le champ', (tester) async {
      await openCustom(tester);

      await tester.enterText(field(), '1500,5');
      await tester.pump();
      expect(fieldText(tester), isEmpty);

      await tester.enterText(field(), '1500');
      await tester.pump();
      await tester.enterText(field(), '1 500a');
      await tester.pump();
      expect(fieldText(tester), '1 500');
    });

    testWidgets('revenir à un montant proposé remplace la saisie', (
      tester,
    ) async {
      await openCustom(tester);
      await tester.enterText(field(), '7777');
      await tester.pump();

      await tapQuickAmount(tester, 2000);
      await tester.pumpAndSettle();

      expect(fieldText(tester), '2 000');
      expect(find.text('Payer 2000 F CFA'), findsOneWidget);
    });

    testWidgets('anglais : « Other amount »', (tester) async {
      useEnglish();
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      expect(find.text('Other amount'), findsOneWidget);
    });
  });

  testWidgets('anglais : compte, portefeuille crédité et bouton Pay traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Top up · Step 2/2'), findsOneWidget);
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(find.text('From Orange Money ••56'), findsOneWidget);
    expect(find.textContaining('Credited to your'), findsOneWidget);

    await tapQuickAmount(tester, 1000);

    expect(find.text('Pay 1000 F CFA'), findsOneWidget);
  });
}
