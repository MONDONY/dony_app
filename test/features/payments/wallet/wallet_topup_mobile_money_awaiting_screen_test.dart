import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_ring.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

/// Écran d'attente de la recharge mobile money : anneau et chrono du
/// serveur, texte selon l'opérateur, ✕ qui ferme sans abandonner, état
/// « Pas encore validé » et échec final traduit.
///
/// L'anneau tourne en boucle : jamais de `pumpAndSettle()` pendant qu'il est
/// monté (il ne se stabilise jamais), toujours des `pump()` bornés.
class _MockCubit extends MockCubit<WalletTopupMobileMoneyState>
    implements WalletTopupMobileMoneyCubit {}

void main() {
  late _MockCubit cubit;
  Object? capturedWalletExtra;
  var didNavigateToWallet = false;

  WalletTopupModel topupWith(MobileMoneyValidationHint hint) =>
      WalletTopupModel(
        topupId: 'topup-1',
        currency: 'XOF',
        provider: 'ORANGE_CIV',
        providerLabel: 'Orange Money',
        msisdnMasked: '+225 07 •• •• 56',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        validationHint: hint,
      );

  final topup = topupWith(MobileMoneyValidationHint.smsLink);

  WalletTopupMobileMoneyAwaiting awaiting([WalletTopupModel? t]) =>
      WalletTopupMobileMoneyAwaiting(
        topup: t ?? topup,
        startedAt: DateTime.now(),
      );

  setUp(() {
    cubit = _MockCubit();
    capturedWalletExtra = null;
    didNavigateToWallet = false;
    when(
      () => cubit.initiate(
        amount: any(named: 'amount'),
        phoneNumber: any(named: 'phoneNumber'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget screen({String? phoneNumber = '+2250748840856'}) =>
      BlocProvider<WalletTopupMobileMoneyCubit>.value(
        value: cubit,
        child: WalletTopupMobileMoneyAwaitingScreen(
          phoneNumber: phoneNumber,
          amount: 5000,
        ),
      );

  Widget buildHarness({String? phoneNumber = '+2250748840856'}) {
    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/mobile-money/awaiting',
      routes: [
        GoRoute(
          path: '/payments/wallet/topup/mobile-money/awaiting',
          builder: (context, state) => screen(phoneNumber: phoneNumber),
        ),
        GoRoute(
          path: '/payments/wallet',
          builder: (context, state) {
            didNavigateToWallet = true;
            capturedWalletExtra = state.extra;
            return const Scaffold(body: Text('Portefeuille'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  /// Écran d'attente poussé par-dessus un écran « choix », pour observer le
  /// retour (pop) et ce qui est fait au cubit en sortant.
  Widget buildStackedHarness() {
    final router = GoRouter(
      initialLocation: '/choice',
      routes: [
        GoRoute(
          path: '/choice',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(
                  '/payments/wallet/topup/mobile-money/awaiting',
                ),
                child: const Text('Ouvrir attente'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/mobile-money/awaiting',
          builder: (context, state) => screen(),
        ),
        GoRoute(
          path: '/payments/wallet',
          builder: (context, state) {
            didNavigateToWallet = true;
            return const Scaffold(body: Text('Portefeuille'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  Future<void> openStacked(WidgetTester tester) async {
    await tester.pumpWidget(buildStackedHarness());
    await tester.pump();
    await tester.tap(find.text('Ouvrir attente'));
    // Transition de page puis démarrage de l'anneau : jamais pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  Future<void> pumpScreen(WidgetTester tester, {String? phoneNumber}) async {
    await tester.pumpWidget(
      buildHarness(phoneNumber: phoneNumber ?? '+2250748840856'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('awaiting_smsLinkHint_showsSmsTexts', (tester) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: awaiting(),
    );

    await pumpScreen(tester);

    expect(find.byType(MobileMoneyAwaitingRing), findsOneWidget);
    expect(find.text('pour valider'), findsOneWidget);
    expect(find.text('SMS envoyé au +225 07 •• •• 56'), findsOneWidget);
    expect(
      find.text('Ouvrez-le et cliquez sur le lien pour valider le paiement.'),
      findsOneWidget,
    );
    // Récapitulatif : montant, compte qui paie, portefeuille crédité.
    expect(find.text('Montant'), findsOneWidget);
    expect(find.text('Depuis'), findsOneWidget);
    expect(find.text('Orange Money ••56'), findsOneWidget);
    expect(find.text('Crédité sur'), findsOneWidget);
    expect(find.textContaining('gardez cet écran ouvert'), findsNothing);
    // Pas de redirection opérateur sans authorizationUrl.
    expect(
      find.byKey(const Key('mobile-money-awaiting-open-authorization')),
      findsNothing,
    );
  });

  testWidgets('awaiting_pinPromptHint_showsPromptTexts', (tester) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: awaiting(topupWith(MobileMoneyValidationHint.pinPrompt)),
    );

    await pumpScreen(tester);

    expect(find.text('Demande envoyée au +225 07 •• •• 56'), findsOneWidget);
    expect(
      find.text(
        "Une fenêtre s'affiche sur votre téléphone : validez avec votre "
        'code secret.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mode de validation inconnu : consigne neutre', (tester) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: awaiting(topupWith(MobileMoneyValidationHint.generic)),
    );

    await pumpScreen(tester);

    expect(find.text('Demande envoyée au +225 07 •• •• 56'), findsOneWidget);
    expect(
      find.text(
        'Validez le paiement sur votre téléphone (SMS ou fenêtre de votre '
        'opérateur).',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'redirection opérateur : bouton « Ouvrir » avec authorizationUrl',
    (tester) async {
      whenListen(
        cubit,
        const Stream<WalletTopupMobileMoneyState>.empty(),
        initialState: awaiting(
          const WalletTopupModel(
            topupId: 'topup-2',
            currency: 'XOF',
            provider: 'WAVE_SEN',
            providerLabel: 'Wave',
            msisdnMasked: '+221 ** ** 56 78',
            authorizationUrl: 'https://pay.wave.com/abc123',
          ),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('Ouvrir Wave'), findsOneWidget);
    },
  );

  testWidgets(
    'awaiting_otherNumberButton_hiddenWhileAwaiting_visibleWhenOverdue',
    (tester) async {
      final states = StreamController<WalletTopupMobileMoneyState>();
      addTearDown(states.close);
      whenListen(cubit, states.stream, initialState: awaiting());

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      // Pendant l'attente : seul le ✕ permet de sortir, aucun second dépôt
      // possible (pawaPay ne sait pas annuler un dépôt).
      expect(find.text('SMS envoyé au +225 07 •• •• 56'), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-money-awaiting-other-number')),
        findsNothing,
      );

      states.add(WalletTopupMobileMoneyOverdue(topup: topup));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('mobile-money-awaiting-other-number')),
        findsOneWidget,
      );
    },
  );

  testWidgets('awaiting_closeButton_detaches_notResets', (tester) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: awaiting(),
    );

    await openStacked(tester);
    expect(find.text('SMS envoyé au +225 07 •• •• 56'), findsOneWidget);

    await tester.tap(find.byType(DonyAppBarBackButton));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // Fin de la transition de page (l'anneau ne tourne plus : écran quitté).
    await tester.pumpAndSettle();
    // On quitte tout le parcours de recharge : jamais l'écran Recharger avec
    // une recharge orpheline derrière lui.
    expect(find.text('Portefeuille'), findsOneWidget);
    expect(find.text('Ouvrir attente'), findsNothing);
    // La recharge continue côté serveur : on arrête seulement de suivre.
    verify(() => cubit.detach()).called(1);
    verifyNever(() => cubit.reset());
  });

  testWidgets('retour système : même traitement que le ✕', (tester) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: awaiting(),
    );

    await openStacked(tester);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(navigator.maybePop());
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Portefeuille'), findsOneWidget);
    verify(() => cubit.detach()).called(1);
    verifyNever(() => cubit.reset());
  });

  testWidgets('montant et devise du récapitulatif lus dans l\'état', (
    tester,
  ) async {
    // Recharge reprise : l'argument de route ne connaît pas le montant.
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: WalletTopupMobileMoneyAwaiting(
        topup: topup,
        startedAt: DateTime.now(),
        amount: 7500,
        resumed: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<WalletTopupMobileMoneyCubit>.value(
          value: cubit,
          child: const WalletTopupMobileMoneyAwaitingScreen(
            phoneNumber: null,
            amount: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    final xof = SupportedCurrency.fromCodeOrDefault('XOF');
    expect(find.text(CurrencyFormatter.format(7500, xof)), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(0, xof)), findsNothing);
    expect(find.text('Portefeuille F CFA'), findsOneWidget);
  });

  testWidgets('awaiting_overdue_showsOverdueTexts_neverNothingDebited', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: WalletTopupMobileMoneyOverdue(topup: topup),
    );

    await pumpScreen(tester);

    expect(find.text('Pas encore validé'), findsOneWidget);
    expect(
      find.text(
        'Si vous validez quand même dans les prochaines minutes, votre solde '
        'sera crédité.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Rien n'), findsNothing);
    expect(find.textContaining('prélevé'), findsNothing);

    // « Renvoyer une demande » : même numéro, même montant.
    await tester.tap(find.text('Renvoyer une demande'));
    await tester.pump();
    verify(
      () => cubit.initiate(amount: 5000, phoneNumber: '+2250748840856'),
    ).called(1);
  });

  testWidgets('Overdue : « Payer avec un autre numéro » abandonne et revient', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream.fromIterable([WalletTopupMobileMoneyOverdue(topup: topup)]),
      initialState: awaiting(),
    );

    await openStacked(tester);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Payer avec un autre numéro'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Ouvrir attente'), findsOneWidget);
    verify(() => cubit.reset()).called(1);
  });

  testWidgets('recharge reprise (numéro inconnu) : pas de « Renvoyer »', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: WalletTopupMobileMoneyOverdue(topup: topup),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: screen(phoneNumber: null)),
    );
    await tester.pump();

    expect(find.text('Renvoyer une demande'), findsNothing);
    expect(find.text('Payer avec un autre numéro'), findsOneWidget);
  });

  testWidgets('awaiting_failed_showsTranslatedReason', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable([
        const WalletTopupMobileMoneyFailed(
          failureCode: 'insufficient-balance',
          failureReason: 'Insufficient balance on your mobile money account.',
        ),
      ]),
      initialState: awaiting(),
    );

    await pumpScreen(tester);

    expect(find.text('Recharge non aboutie'), findsOneWidget);
    // Texte de l'app (langue de l'app), pas celui renvoyé par le back.
    expect(
      find.text('Solde insuffisant sur votre compte mobile money.'),
      findsOneWidget,
    );
    expect(find.text('Renvoyer une demande'), findsOneWidget);
    expect(find.text('Payer avec un autre numéro'), findsOneWidget);
  });

  testWidgets('échec avec un code inconnu : motif du back, sinon générique', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: const WalletTopupMobileMoneyFailed(
        failureCode: 'new-code',
        failureReason: 'Motif traduit par le back.',
      ),
    );
    await pumpScreen(tester);
    expect(find.text('Motif traduit par le back.'), findsOneWidget);
  });

  testWidgets('échec sans code ni motif : message générique', (tester) async {
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: const WalletTopupMobileMoneyFailed(),
    );
    await pumpScreen(tester);
    expect(
      find.text("Le paiement a été refusé par l'opérateur."),
      findsOneWidget,
    );
  });

  testWidgets('Confirmed -> retour au portefeuille avec le statut en extra', (
    tester,
  ) async {
    const status = WalletTopupStatusModel(
      topupId: 'topup-1',
      status: 'CONFIRMED',
      amount: 5000,
      currency: 'XOF',
      provider: 'ORANGE_CIV',
      providerLabel: 'Orange Money',
      msisdnMasked: '+225 07 •• •• 56',
      walletBalance: 15000,
    );
    whenListen(
      cubit,
      Stream.fromIterable([const WalletTopupMobileMoneyConfirmed(status)]),
      initialState: awaiting(),
    );

    await pumpScreen(tester);

    expect(didNavigateToWallet, isTrue);
    expect(capturedWalletExtra, {'topupConfirmed': status});
  });

  testWidgets(
    'IMPORTANT — Error (réseau coupé pendant « Renvoyer ») : message et '
    'bouton de reprise, jamais une roue infinie',
    (tester) async {
      const failure = NetworkException('boom');
      whenListen(
        cubit,
        Stream.fromIterable([const WalletTopupMobileMoneyError(failure)]),
        initialState: const WalletTopupMobileMoneyFailed(failureCode: 'other'),
      );

      await pumpScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text(ErrorPresenter.resolve(failure).message),
        findsOneWidget,
      );

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(
        () => cubit.initiate(amount: 5000, phoneNumber: '+2250748840856'),
      ).called(1);
    },
  );

  test('chaque code d\'échec Yadony a son texte dans la langue de l\'app', () {
    final l = lookupAppLocalizations(const Locale('fr'));
    const expected = {
      'insufficient-balance':
          'Solde insuffisant sur votre compte mobile money.',
      'not-approved': "Le paiement n'a pas été validé sur votre téléphone.",
      'payer-limit-reached':
          'Votre opérateur a refusé : plafond de paiement atteint.',
      'invalid-number': 'Ce numéro ne peut pas payer par mobile money.',
      'provider-unavailable':
          'Votre opérateur est indisponible pour le moment. Réessayez plus tard.',
      'expired': "La demande a expiré avant d'être validée.",
      'other': "Le paiement a été refusé par l'opérateur.",
    };
    expected.forEach((code, text) {
      expect(
        walletTopupFailureMessage(
          l,
          WalletTopupMobileMoneyFailed(failureCode: code, failureReason: 'x'),
        ),
        text,
        reason: code,
      );
    });
  });

  group('anglais', () {
    testWidgets('textes traduits de l\'attente', (tester) async {
      useEnglish();
      whenListen(
        cubit,
        const Stream<WalletTopupMobileMoneyState>.empty(),
        initialState: awaiting(),
      );

      await pumpScreen(tester);

      expect(find.text('Mobile money top-up'), findsOneWidget);
      expect(find.text('to approve'), findsOneWidget);
      expect(find.text('SMS sent to +225 07 •• •• 56'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('From'), findsOneWidget);
      expect(find.text('Credited to'), findsOneWidget);
    });

    testWidgets('échec traduit dans la langue de l\'app', (tester) async {
      useEnglish();
      whenListen(
        cubit,
        const Stream<WalletTopupMobileMoneyState>.empty(),
        initialState: const WalletTopupMobileMoneyFailed(
          failureCode: 'not-approved',
          failureReason: "Le paiement n'a pas été validé sur votre téléphone.",
        ),
      );

      await pumpScreen(tester);

      expect(
        find.text('The payment was not approved on your phone.'),
        findsOneWidget,
      );
      expect(find.text('Send a new request'), findsOneWidget);
    });
  });
}
