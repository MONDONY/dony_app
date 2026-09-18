import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_selection.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

/// Écran de choix de méthode de recharge : tuile mobile money (numéro +
/// checklist d'opérateurs), garde du bouton « Suivant » et parcours Stripe
/// inchangé.
class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository repo;
  late MockAnalyticsBackend analyticsBackend;
  WalletTopupMethodSelection? capturedSelection;

  const catalog = MobileMoneyProviderCatalog(
    country: 'SN',
    currency: 'XOF',
    msisdnMasked: '+221 ** ** 12 34',
    detected: 'ORANGE_SEN',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_SEN',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_SEN', label: 'Wave'),
    ],
  );

  // Aucun opérateur détecté (`detected: null`) : `selectedProvider` démarre
  // vide, condition nécessaire pour observer le geste « Tous les réseaux »
  // (sinon un opérateur est déjà coché et l'effet du header serait masqué
  // par ce pré-remplissage).
  const catalogNoDetection = MobileMoneyProviderCatalog(
    country: 'SN',
    currency: 'XOF',
    msisdnMasked: '+225 ** ** 12 34',
    providers: [
      MobileMoneyProviderOption(code: 'ORANGE_CIV', label: 'Orange Money'),
      MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave'),
      MobileMoneyProviderOption(code: 'MTN_CIV', label: 'MTN MoMo'),
    ],
  );

  const topup = WalletTopupModel(
    topupId: 'topup-1',
    currency: 'XOF',
    provider: 'ORANGE_SEN',
    providerLabel: 'Orange Money',
    msisdnMasked: '+221 ** ** 12 34',
  );

  WalletTopupStatusModel statusFor(String status) => WalletTopupStatusModel(
    topupId: 'topup-1',
    status: status,
    amount: 5000,
    currency: 'XOF',
    provider: 'ORANGE_SEN',
    providerLabel: 'Orange Money',
    msisdnMasked: '+221 ** ** 12 34',
  );

  setUp(() {
    repo = _MockWalletRepository();
    analyticsBackend = MockAnalyticsBackend();
    capturedSelection = null;
    when(() => repo.topupProviders(any())).thenAnswer((_) async => catalog);
    when(
      () => repo.topupMobileMoney(
        amount: any(named: 'amount'),
        phoneNumber: any(named: 'phoneNumber'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer((_) async => topup);
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/method',
      routes: [
        GoRoute(
          path: '/payments/wallet/topup/method',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>(
                create: (_) => WalletTopupMobileMoneyCubit(
                  repo,
                  makeEnabledAnalytics(analyticsBackend),
                ),
                child: const WalletTopupMethodScreen(),
              ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/amount',
          builder: (context, state) {
            capturedSelection = state.extra as WalletTopupMethodSelection;
            return const Scaffold(body: Text('Montant'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  /// Sélectionne la tuile mobile money, laisse le temps à sa section (avec
  /// ses `.animate()`) de se monter complètement, puis saisit un numéro et
  /// perd le focus pour déclencher `loadProviders`.
  Future<void> selectMobileMoneyAndTypePhone(WidgetTester tester) async {
    await tester.tap(find.text('Mobile money'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wallet-topup-payer-phone-field')),
      '+221 77 123 45 67',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('tuile mobile money visible et sélectionnable', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Mobile money'), findsOneWidget);
    expect(find.text('Orange Money, Wave, MTN MoMo'), findsOneWidget);

    await tester.tap(find.text('Mobile money'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('wallet-topup-payer-phone-field')),
      findsOneWidget,
    );
  });

  testWidgets(
    'saisie du numéro puis perte de focus : opérateurs chargés, opérateur '
    'détecté coché, bouton actif',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      // Bouton désactivé tant qu'aucune méthode n'est choisie.
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNull,
      );

      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();

      // Toujours désactivé : aucun opérateur prêt.
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        '+221 77 123 45 67',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('network-ORANGE_SEN')), findsOneWidget);
      final orangeTile = tester.widget<DonyOperatorTile>(
        find.byKey(const Key('network-ORANGE_SEN')),
      );
      expect(orangeTile.selected, isTrue);

      final waveTile = tester.widget<DonyOperatorTile>(
        find.byKey(const Key('network-WAVE_SEN')),
      );
      expect(waveTile.selected, isFalse);

      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'Stripe inchangé : sélection puis Suivant transmet method STRIPE sans cubit',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carte bancaire'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Suivant → Montant'));
      await tester.pumpAndSettle();

      expect(capturedSelection, isNotNull);
      expect(capturedSelection!.method, 'STRIPE');
      expect(capturedSelection!.cubit, isNull);
      expect(capturedSelection!.phoneNumber, isNull);
    },
  );

  testWidgets(
    'mobile money : Suivant transmet numéro, opérateur, devise et la même '
    'instance de cubit',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      final cubit = BlocProvider.of<WalletTopupMobileMoneyCubit>(
        tester.element(find.byType(WalletTopupMethodScreen)),
      );

      await selectMobileMoneyAndTypePhone(tester);

      await tester.tap(find.text('Suivant → Montant'));
      await tester.pumpAndSettle();

      expect(capturedSelection, isNotNull);
      expect(capturedSelection!.method, 'MOBILE_MONEY');
      expect(capturedSelection!.phoneNumber, '+221771234567');
      expect(capturedSelection!.provider, 'ORANGE_SEN');
      expect(capturedSelection!.currency, 'XOF');
      expect(capturedSelection!.cubit, same(cubit));
    },
  );

  testWidgets('IMPORTANT — reprise après « Payer avec un autre numéro » depuis '
      "l'attente : l'écran de choix RÉEL redevient utilisable (numéro "
      'rechargeable, opérateurs, Suivant), plus aucun sondage, aucune '
      'confirmation tardive pour la recharge abandonnée', (tester) async {
    final slowStatus = Completer<WalletTopupStatusModel>();
    when(() => repo.topupStatus(any())).thenAnswer((_) => slowStatus.future);

    final cubit = WalletTopupMobileMoneyCubit(
      repo,
      makeEnabledAnalytics(analyticsBackend),
    );
    addTearDown(cubit.close);

    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/method',
      routes: [
        GoRoute(
          path: '/payments/wallet/topup/method',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>.value(
                value: cubit,
                child: const WalletTopupMethodScreen(),
              ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/mobile-money/awaiting',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>.value(
                value: cubit,
                child: const WalletTopupMobileMoneyAwaitingScreen(
                  phoneNumber: '+221771234567',
                  amount: 5000,
                ),
              ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    // Parcours réel jusqu'à un opérateur prêt (comme les tests
    // précédents), puis initiation directe sur le cubit — l'écran de
    // montant n'est pas en cause dans cette régression, déjà couvert par
    // ailleurs.
    await tester.tap(find.text('Mobile money'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wallet-topup-payer-phone-field')),
      '+221 77 123 45 67',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(cubit.state, isA<WalletTopupMobileMoneyProvidersReady>());

    unawaited(cubit.initiate(amount: 5000, phoneNumber: '+221771234567'));
    await tester.pump();
    await tester.pump();
    expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

    // Le sondage tourne : un tick fait partir une requête de statut qui
    // reste en vol (jamais résolue avant la reprise ci-dessous).
    await tester.pump(WalletTopupMobileMoneyCubit.pollInterval);

    unawaited(router.push('/payments/wallet/topup/mobile-money/awaiting'));
    // Jamais pumpAndSettle() : l'icône pulsée de l'écran d'attente tourne
    // en boucle, la pile ne se stabilise jamais.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Valide le paiement sur ton téléphone'), findsOneWidget);

    await tester.tap(find.text('Payer avec un autre numéro'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // De retour sur l'écran de choix RÉEL (jamais dépilé, `_selected` et
    // le numéro tapé y survivent), le cubit est bien revenu à Idle.
    expect(find.byType(WalletTopupMethodScreen), findsOneWidget);
    expect(cubit.state, isA<WalletTopupMobileMoneyIdle>());
    expect(
      find.text('+221 77 123 45 67'),
      findsOneWidget,
      reason: 'le champ numéro garde ce qui avait été saisi',
    );
    // Aucun opérateur : Suivant redevient inactif tant que rien n'est
    // rechargé.
    expect(
      tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
      isNull,
    );

    // Reperdre le focus SANS changer le numéro relance loadProviders :
    // le cubit est Idle (recharge abandonnée), pas ProvidersReady.
    // `enterText` (re-saisie de la même valeur) prend le focus par
    // recherche de State, sans dépendre d'un tap sur des coordonnées
    // écran — robuste même si un reliquat d'overlay de sélection texte
    // (barre à outils / poignées) survit encore à cet endroit après la
    // navigation aller-retour.
    final phoneField = find.byKey(const Key('wallet-topup-payer-phone-field'));
    await tester.enterText(phoneField, '+221 77 123 45 67');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    verify(() => repo.topupProviders('+221771234567')).called(2);
    expect(find.byKey(const Key('network-ORANGE_SEN')), findsOneWidget);
    expect(
      tester
          .widget<DonyOperatorTile>(find.byKey(const Key('network-ORANGE_SEN')))
          .selected,
      isTrue,
    );
    expect(
      tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
      isNotNull,
    );

    // La réponse tardive du sondage abandonné (même CONFIRMED) ne doit
    // plus avoir aucun effet : pas de résurrection, pas d'event confirmed.
    slowStatus.complete(statusFor('CONFIRMED'));
    await tester.pump();
    expect(cubit.state, isNot(isA<WalletTopupMobileMoneyConfirmed>()));
    verifyNever(
      () => analyticsBackend.capture(
        AnalyticsEvents.walletTopupMobileMoneyConfirmed,
        any(),
      ),
    );
  });

  testWidgets(
    '« Tous les réseaux » (aucune sélection préalable, 3 opérateurs) ne '
    'choisit rien au hasard : la sélection reste vide, Suivant inactif',
    (tester) async {
      when(
        () => repo.topupProviders('+225771234567'),
      ).thenAnswer((_) async => catalogNoDetection);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        '+225 77 123 45 67',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Aucun opérateur détecté : rien n'est coché, Suivant inactif.
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNull,
      );
      for (final code in ['ORANGE_CIV', 'WAVE_CIV', 'MTN_CIV']) {
        expect(
          tester
              .widget<DonyOperatorTile>(find.byKey(Key('network-$code')))
              .selected,
          isFalse,
        );
      }

      // Coche « Tous les réseaux » : geste ambigu pour un choix exclusif
      // (3 réseaux cochés à la fois) — ignoré plutôt que d'en retenir un.
      await tester.tap(find.byKey(const Key('network-all')));
      await tester.pump();

      for (final code in ['ORANGE_CIV', 'WAVE_CIV', 'MTN_CIV']) {
        expect(
          tester
              .widget<DonyOperatorTile>(find.byKey(Key('network-$code')))
              .selected,
          isFalse,
          reason: '$code ne doit pas être coché au hasard',
        );
      }
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNull,
        reason: 'toujours aucun opérateur choisi, Suivant reste inactif',
      );

      // Cocher un réseau précis fonctionne normalement (pas de régression
      // sur le choix individuel).
      await tester.tap(find.byKey(const Key('network-WAVE_CIV')));
      await tester.pump();

      expect(
        tester
            .widget<DonyOperatorTile>(find.byKey(const Key('network-WAVE_CIV')))
            .selected,
        isTrue,
      );
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNotNull,
      );
    },
  );
}
