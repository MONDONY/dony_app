import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_code_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_availability_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_code_redemption_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_selection.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_args.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_screen.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';
import '../../../helpers/payer_account_test_doubles.dart';

/// Écran de choix de méthode de recharge : tuile mobile money (numéro +
/// checklist d'opérateurs), garde du bouton « Suivant » et parcours Stripe
/// inchangé.
class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWalletRemoteDatasource extends Mock
    implements WalletRemoteDatasource {}

// Tutoriel de la recharge mobile money (FLUTTER-8G) : la carte du haut de
// l'écran lit HelpCenterBloc.
const _helpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "tuto_recharge_mobile_money",
      "title": "Recharger avec le mobile money",
      "description": "Orange Money, Wave ou MTN MoMo.",
      "youtubeVideoId": "iBQQPfrBioQ",
      "order": 1,
      "active": true,
      "contexts": ["walletTopup"]
    }
  ]
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

void main() {
  late _MockWalletRepository repo;

  /// Dépôt utilisé par la SONDE de disponibilité : le mock par défaut, ou un
  /// vrai [WalletRepository] quand un test veut vérifier la décision réelle
  /// prise sur le code d'erreur du backend.
  late WalletRepository availabilityRepo;
  late MockAnalyticsBackend analyticsBackend;

  /// Composant « compte qui paie ». Par défaut en `legacy` (back sans
  /// catalogue des pays) : les tests historiques ci-dessous couvrent
  /// l'ancien champ numéro, gardé pour ce cas.
  late MockPayerAccountCubit payer;
  WalletTopupMethodSelection? capturedSelection;
  WalletTopupMobileMoneyAwaitingArgs? capturedAwaitingArgs;
  Object? popResult;

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
    availabilityRepo = repo;
    analyticsBackend = MockAnalyticsBackend();
    capturedSelection = null;
    capturedAwaitingArgs = null;
    popResult = null;
    payer = MockPayerAccountCubit();
    final payerStates = stubPayerAccount(
      payer,
      const PayerAccountState(status: PayerAccountStatus.legacy),
    );
    addTearDown(payerStates.close);
    if (getIt.isRegistered<WalletTopupCodeCubit>()) {
      getIt.unregister<WalletTopupCodeCubit>();
    }
    getIt.registerFactory<WalletTopupCodeCubit>(
      () => WalletTopupCodeCubit(repo),
    );
    when(
      () => repo.isMobileMoneyTopupAvailable(),
    ).thenAnswer((_) async => true);
    when(() => repo.topupProviders(any())).thenAnswer((_) async => catalog);
    // Aucune recharge en cours à reprendre, sauf mention contraire.
    when(() => repo.pendingTopup()).thenAnswer((_) async => null);
    when(
      () => repo.topupMobileMoney(
        amount: any(named: 'amount'),
        phoneNumber: any(named: 'phoneNumber'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer((_) async => topup);
  });

  /// L'écran de choix a besoin des deux cubits que pose sa route réelle :
  /// celui de la recharge et celui de la sonde de disponibilité du rail
  /// mobile money (sans quoi la tuile n'apparaît jamais).
  Widget wrapMethodScreen(WalletTopupMobileMoneyCubit mmCubit) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HelpCenterBloc>(
          create: (_) => HelpCenterBloc(
            HelpCenterRepository(
              const _StaticHelpCenterSource(_helpConfigJson),
              fallbackJsonLoader: () async => _helpConfigJson,
            ),
            makeDisabledAnalytics(MockAnalyticsBackend()),
          )..add(const HelpCenterLoadRequested()),
        ),
        BlocProvider<WalletTopupMobileMoneyCubit>.value(value: mmCubit),
        BlocProvider<PayerAccountCubit>.value(value: payer),
        BlocProvider<WalletTopupMobileMoneyAvailabilityCubit>(
          create: (_) =>
              WalletTopupMobileMoneyAvailabilityCubit(availabilityRepo)
                ..probe(),
        ),
      ],
      child: const WalletTopupMethodScreen(),
    );
  }

  Widget buildHarness({ThemeData? theme, bool withParent = false}) {
    final mmCubit = WalletTopupMobileMoneyCubit(
      repo,
      makeEnabledAnalytics(analyticsBackend),
    );
    addTearDown(mmCubit.close);
    final router = GoRouter(
      initialLocation: withParent ? '/' : '/payments/wallet/topup/method',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popResult = await context.push<bool>(
                  '/payments/wallet/topup/method',
                );
              },
              child: const Text('Ouvrir recharge'),
            ),
          ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/method',
          builder: (context, state) => wrapMethodScreen(mmCubit),
        ),
        GoRoute(
          path: '/payments/wallet/topup/amount',
          builder: (context, state) {
            capturedSelection = state.extra as WalletTopupMethodSelection;
            return const Scaffold(body: Text('Montant'));
          },
        ),
        GoRoute(
          path: '/payments/wallet/topup/mobile-money/awaiting',
          builder: (context, state) {
            capturedAwaitingArgs =
                state.extra as WalletTopupMobileMoneyAwaitingArgs;
            return const Scaffold(body: Text('Attente'));
          },
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: theme ?? AppTheme.light(),
    );
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

  testWidgets(
    'tutoriel vidéo de la recharge mobile money en tête (FLUTTER-8G)',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('contextual-tutorial-card')), findsOneWidget);
    },
  );

  testWidgets('tuile code de recharge visible même sans mobile money', (
    tester,
  ) async {
    when(
      () => repo.isMobileMoneyTopupAvailable(),
    ).thenAnswer((_) async => false);
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();
    expect(find.text("J'ai un code de recharge"), findsOneWidget);
  });

  testWidgets('code accepté : snackbar avec la devise du code puis retour', (
    tester,
  ) async {
    DonySnackbar.clearDedup();
    when(() => repo.redeemTopupCode(any())).thenAnswer(
      (_) async => const WalletTopupCodeRedemptionModel(
        amount: 2000,
        currency: 'XOF',
        balance: 2000,
      ),
    );
    await tester.pumpWidget(buildHarness(withParent: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir recharge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("J'ai un code de recharge"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'DAKAR2000');
    await tester.pump();
    await tester.tap(find.text('Valider le code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('+'), findsWidgets);
    expect(find.textContaining('ajoutés à votre solde'), findsOneWidget);
    expect(
      (tester.widget(find.textContaining('ajoutés à votre solde')) as Text)
          .data,
      startsWith('+'),
    );
    expect(
      find.textContaining('XOF').evaluate().isNotEmpty ||
          find.textContaining('F CFA').evaluate().isNotEmpty,
      isTrue,
    );
    expect(popResult, isTrue);
    expect(find.text('Ouvrir recharge'), findsOneWidget);
  });

  testWidgets('tuile mobile money visible et sélectionnable', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Mobile money'), findsOneWidget);
    expect(find.text('Orange Money, MTN MoMo, Moov'), findsOneWidget);

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

  // Sentry FLUTTER-8B : sur le pavé téléphone iOS, rien n'invitait à quitter
  // le champ, les opérateurs ne se chargeaient jamais et le bouton restait
  // grisé sans explication.
  group('FLUTTER-8B — numéro saisi sans quitter le champ', () {
    testWidgets('consigne affichée tant que rien n\'est chargé, puis '
        'opérateurs chargés après une pause de saisie, bouton actif', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wallet-topup-phone-hint')), findsOneWidget);
      expect(
        find.text(
          'Saisissez votre numéro mobile money : vos opérateurs s\'affichent ici.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        '+221 77 123 45 67',
      );
      await tester.pump(const Duration(milliseconds: 300));
      verifyNever(() => repo.topupProviders(any()));

      await tester.pump(walletTopupPhoneDebounceDelay);
      await tester.pumpAndSettle();

      verify(() => repo.topupProviders('+221771234567')).called(1);
      // Le champ garde le focus : c'est bien la pause, pas un blur.
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      expect(find.byKey(const Key('wallet-topup-phone-hint')), findsNothing);
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNotNull,
      );

      // Le blur qui suit ne relance pas le même numéro.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      verifyNever(() => repo.topupProviders(any()));
    });

    testWidgets('numéro encore incomplet : aucun appel au serveur', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        '+221 77',
      );
      await tester.pump(walletTopupPhoneDebounceDelay * 2);
      await tester.pumpAndSettle();

      verifyNever(() => repo.topupProviders(any()));
      expect(find.byKey(const Key('wallet-topup-phone-hint')), findsOneWidget);
    });

    testWidgets('touche « Terminé » du clavier : quitte le champ et charge', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        '+221 77 123 45 67',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(() => repo.topupProviders('+221771234567')).called(1);
      expect(find.byKey(const Key('network-ORANGE_SEN')), findsOneWidget);

      // La pause de saisie expire ensuite sans relancer le même numéro.
      await tester.pump(walletTopupPhoneDebounceDelay);
      await tester.pumpAndSettle();
      verifyNever(() => repo.topupProviders(any()));
    });
  });

  testWidgets('thème sombre : la carte sélectionnée garde un fond sombre, '
      'lisible sous le texte clair (FLUTTER-8B)', (tester) async {
    final dark = AppTheme.dark();
    await tester.pumpWidget(buildHarness(theme: dark));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile money'));
    await tester.pumpAndSettle();

    final card = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('Mobile money'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final bg = (card.decoration! as BoxDecoration).color!;
    expect(bg, isNot(DonyColors.blue50));
    expect(bg.computeLuminance(), lessThan(0.2));
    expect(dark.colorScheme.onSurface.computeLuminance(), greaterThan(0.5));
  });

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
      expect(capturedSelection!.currency, 'XOF');
      expect(capturedSelection!.cubit, same(cubit));
    },
  );

  testWidgets('IMPORTANT — reprise après « Payer avec un autre numéro » depuis '
      "l'attente échue : l'écran de choix RÉEL redevient utilisable (numéro "
      'rechargeable, opérateurs, Suivant), plus aucun sondage, aucune '
      'confirmation tardive pour la recharge abandonnée', (tester) async {
    final slowStatus = Completer<WalletTopupStatusModel>();
    when(() => repo.topupStatus(any())).thenAnswer((_) => slowStatus.future);
    // Échéance déjà passée : « Payer avec un autre numéro » n'est proposé
    // qu'à partir de là (pawaPay ne sait pas annuler un dépôt).
    when(
      () => repo.topupMobileMoney(
        amount: any(named: 'amount'),
        phoneNumber: any(named: 'phoneNumber'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer(
      (_) async => WalletTopupModel(
        topupId: 'topup-1',
        currency: 'XOF',
        provider: 'ORANGE_SEN',
        providerLabel: 'Orange Money',
        msisdnMasked: '+221 ** ** 12 34',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );

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
          builder: (context, state) => wrapMethodScreen(cubit),
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

    // Le sondage tourne : un tick constate l'échéance passée (Overdue) et
    // fait partir une requête de statut qui reste en vol (jamais résolue
    // avant la reprise ci-dessous).
    await tester.pump(WalletTopupMobileMoneyCubit.pollInterval);
    expect(cubit.state, isA<WalletTopupMobileMoneyOverdue>());

    unawaited(router.push('/payments/wallet/topup/mobile-money/awaiting'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Pas encore validé'), findsOneWidget);

    await tester.tap(find.text('Payer avec un autre numéro'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // De retour sur l'écran de choix RÉEL (jamais dépilé, `_selected` et
    // le numéro tapé y survivent) : la recharge est abandonnée (le sondage
    // est coupé) et le catalogue se recharge tout seul, si bien que l'écran
    // est immédiatement réutilisable — y compris pour repartir sur un autre
    // numéro, qu'il suffit de saisir.
    await tester.pumpAndSettle();
    expect(find.byType(WalletTopupMethodScreen), findsOneWidget);
    expect(cubit.state, isA<WalletTopupMobileMoneyProvidersReady>());
    expect(
      find.text('+221 77 123 45 67'),
      findsOneWidget,
      reason: 'le champ numéro garde ce qui avait été saisi',
    );

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
      await tester.ensureVisible(find.byKey(const Key('network-WAVE_CIV')));
      await tester.pumpAndSettle();
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

  testWidgets(
    'CRITIQUE — backend sans le rail mobile money : la tuile est absente, '
    "l'écran reste celui d'avant (carte bancaire seule, utilisable)",
    (tester) async {
      when(
        () => repo.isMobileMoneyTopupAvailable(),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.text('Mobile money'), findsNothing);
      // Le tutoriel couvre aussi la recharge par carte (FLUTTER-AB).
      expect(find.byKey(const Key('contextual-tutorial-card')), findsOneWidget);
      expect(find.text('Carte bancaire'), findsOneWidget);

      await tester.tap(find.text('Carte bancaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suivant → Montant'));
      await tester.pumpAndSettle();

      expect(capturedSelection?.method, 'STRIPE');
    },
  );

  testWidgets('la tuile mobile money apparaît dès que la sonde réussit', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Mobile money'), findsOneWidget);
    verify(() => repo.isMobileMoneyTopupAvailable()).called(1);
  });

  testWidgets(
    'CRITIQUE — ✕ de l\'écran d\'attente : retour à l\'écran de choix sans '
    'abandonner la recharge, plus aucun sondage',
    (tester) async {
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
            builder: (context, state) => wrapMethodScreen(cubit),
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

      await selectMobileMoneyAndTypePhone(tester);
      expect(cubit.state, isA<WalletTopupMobileMoneyProvidersReady>());

      unawaited(cubit.initiate(amount: 5000, phoneNumber: '+221771234567'));
      await tester.pump();
      await tester.pump();
      expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

      // Le sondage tourne : une requête de statut part et reste en vol.
      await tester.pump(WalletTopupMobileMoneyCubit.pollInterval);

      unawaited(router.push('/payments/wallet/topup/mobile-money/awaiting'));
      // Jamais pumpAndSettle() : l'anneau tourne en boucle.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Demande envoyée au +221 ** ** 12 34'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(WalletTopupMobileMoneyAwaitingScreen),
          matching: find.byType(DonyAppBarBackButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(WalletTopupMethodScreen), findsOneWidget);
      // La recharge n'est pas abandonnée : le serveur la suit et notifie.
      expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

      slowStatus.complete(statusFor('PENDING'));
      await tester.pump();
      await tester.pump(WalletTopupMobileMoneyCubit.pollInterval * 2);
      // Un seul sondage au total : celui parti avant le ✕.
      verify(() => repo.topupStatus(any())).called(1);
    },
  );

  testWidgets(
    'CRITIQUE — la confirmation qui arrive alors que l\'utilisateur est revenu '
    "sur l'écran de choix emmène au portefeuille avec le bandeau",
    (tester) async {
      when(
        () => repo.topupStatus(any()),
      ).thenAnswer((_) async => statusFor('CONFIRMED'));

      Object? walletExtra;
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
            builder: (context, state) => wrapMethodScreen(cubit),
          ),
          GoRoute(
            path: '/payments/wallet',
            builder: (context, state) {
              walletExtra = state.extra;
              return const Scaffold(body: Text('Portefeuille'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      );
      await tester.pumpAndSettle();
      await selectMobileMoneyAndTypePhone(tester);

      unawaited(cubit.initiate(amount: 5000, phoneNumber: '+221771234567'));
      await tester.pump();
      await tester.pump();
      expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());

      // L'écran d'attente n'est pas (ou plus) là : sans ce filet, personne
      // n'annoncerait la confirmation et l'utilisateur croirait à un échec.
      await tester.pump(WalletTopupMobileMoneyCubit.pollInterval);
      await tester.pumpAndSettle();

      expect(find.text('Portefeuille'), findsOneWidget);
      expect(
        (walletExtra as Map<String, dynamic>?)?['topupConfirmed'],
        isA<WalletTopupStatusModel>(),
      );
    },
  );

  testWidgets(
    'IMPORTANT — une erreur d\'initiation ne produit qu\'un seul message : '
    "l'écran de choix, resté monté dessous, se tait",
    (tester) async {
      const failure = NetworkException('boom');
      when(
        () => repo.topupMobileMoney(
          amount: any(named: 'amount'),
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ).thenThrow(failure);

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
            builder: (context, state) => wrapMethodScreen(cubit),
          ),
          // Mime l'écran de montant : lui aussi présente l'erreur.
          GoRoute(
            path: '/payments/wallet/topup/amount',
            builder: (context, state) =>
                BlocProvider<WalletTopupMobileMoneyCubit>.value(
                  value: cubit,
                  child:
                      BlocListener<
                        WalletTopupMobileMoneyCubit,
                        WalletTopupMobileMoneyState
                      >(
                        listenWhen: (previous, current) =>
                            previous.runtimeType != current.runtimeType,
                        listener: (context, state) {
                          if (state is WalletTopupMobileMoneyError) {
                            unawaited(
                              ErrorPresenter.show(context, state.error),
                            );
                          }
                        },
                        child: const Scaffold(body: Text('Montant')),
                      ),
                ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      );
      await tester.pumpAndSettle();
      await selectMobileMoneyAndTypePhone(tester);

      unawaited(router.push('/payments/wallet/topup/amount'));
      await tester.pumpAndSettle();

      unawaited(cubit.initiate(amount: 5000, phoneNumber: '+221771234567'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final message = ErrorPresenter.resolve(failure).message;
      expect(find.text(message), findsOneWidget);
    },
  );

  testWidgets(
    'IMPORTANT — après un échec, ressaisir LE MÊME numéro recharge bien les '
    'opérateurs',
    (tester) async {
      var calls = 0;
      when(() => repo.topupProviders('+221771234567')).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw const NetworkException('boom');
        }
        return catalog;
      });

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      await selectMobileMoneyAndTypePhone(tester);

      expect(find.byKey(const Key('network-ORANGE_SEN')), findsNothing);

      // Même numéro, même geste : le cache de numéro ne doit pas bloquer la
      // relance puisque plus aucun catalogue n'est affiché.
      await tester.enterText(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        '+221 77 123 45 67',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byKey(const Key('network-ORANGE_SEN')), findsOneWidget);
    },
  );

  testWidgets('anglais : titre, tuiles et bouton Suivant traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Top up · Step 1/2'), findsOneWidget);
    expect(find.text('TOP-UP METHOD'), findsOneWidget);
    expect(find.text('Credit card'), findsOneWidget);
    expect(find.text('Mobile money'), findsOneWidget);

    await tester.tap(find.text('Credit card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next → Amount'));
    await tester.pumpAndSettle();

    expect(capturedSelection?.method, 'STRIPE');
  });

  group('sonde de capacité jugée sur le code d\'erreur du backend', () {
    /// Vraie chaîne repository → datasource : la sonde sans corps échoue
    /// toujours, c'est le CODE de l'erreur qui décide.
    void probeFails(Object error) {
      final datasource = _MockWalletRemoteDatasource();
      when(() => datasource.topupProvidersProbe()).thenThrow(error);
      availabilityRepo = WalletRepository(datasource);
    }

    DioException wrapped(AppException e) => DioException(
      requestOptions: RequestOptions(path: '/wallet/topup/providers'),
      error: e,
    );

    testWidgets(
      'CRITIQUE — 422 topup-phone-required (réponse normale de la sonde) : '
      'la tuile mobile money est bien affichée',
      (tester) async {
        probeFails(
          wrapped(
            const ValidationException(
              'Indiquez le numéro mobile money qui paie la recharge.',
              code: 'topup-phone-required',
            ),
          ),
        );

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        expect(find.text('Mobile money'), findsOneWidget);
      },
    );

    testWidgets('422 mobile-money-disabled : tuile masquée', (tester) async {
      probeFails(
        wrapped(
          const ValidationException(
            'Rail désactivé',
            code: 'mobile-money-disabled',
          ),
        ),
      );

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.text('Mobile money'), findsNothing);
      expect(find.text('Carte bancaire'), findsOneWidget);
    });

    testWidgets('404 (backend sans le lot 2) : tuile masquée', (tester) async {
      probeFails(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/topup/providers'),
          response: Response(
            requestOptions: RequestOptions(path: '/wallet/topup/providers'),
            statusCode: 404,
          ),
        ),
      );

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.text('Mobile money'), findsNothing);
      expect(find.text('Carte bancaire'), findsOneWidget);
    });
  });

  group('compte qui paie (pays, opérateur, numéro)', () {
    /// Remplace l'état `legacy` du harnais par [initial] ; les états suivants
    /// passent par le contrôleur rendu.
    StreamController<PayerAccountState> payerStarts(PayerAccountState initial) {
      final controller = stubPayerAccount(payer, initial);
      addTearDown(controller.close);
      return controller;
    }

    DonyButton cta(WidgetTester tester) =>
        tester.widget<DonyButton>(find.byType(DonyButton).last);

    Future<void> openMobileMoney(WidgetTester tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'methodScreen_mobileMoney_showsCountryField_notLegacyPhoneField',
      (tester) async {
        payerStarts(kPayerReady);
        await openMobileMoney(tester);

        expect(find.byKey(const Key('mm-country-field')), findsOneWidget);
        expect(
          find.byKey(const Key('wallet-topup-payer-phone-field')),
          findsNothing,
        );
        expect(find.text('COMPTE QUI PAIE'), findsOneWidget);
        // Les trois lignes du moyen restent visibles.
        expect(find.text('Carte bancaire'), findsOneWidget);
        expect(find.text("J'ai un code de recharge"), findsOneWidget);
        expect(cta(tester).onPressed, isNull);
      },
    );

    testWidgets('methodScreen_legacyState_showsOldPhoneField', (tester) async {
      await openMobileMoney(tester);

      expect(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mm-country-field')), findsNothing);
    });

    testWidgets('upcomingCountry_ctaBecomesSwitchToCard', (tester) async {
      payerStarts(kPayerReady.copyWith(unavailableCountry: 'ML'));
      await openMobileMoney(tester);

      expect(find.text('Recharger par carte'), findsOneWidget);
      expect(find.text('Suivant → Montant'), findsNothing);
      expect(cta(tester).onPressed, isNotNull);

      await tester.tap(find.text('Recharger par carte'));
      await tester.pumpAndSettle();

      verify(() => payer.switchToCardTapped()).called(1);
      // Carte bancaire sélectionnée : le bloc mobile money se replie et le
      // bouton reprend « Suivant », actif.
      expect(find.byKey(const Key('mm-country-field')), findsNothing);
      expect(find.text('Suivant → Montant'), findsOneWidget);
      expect(cta(tester).onPressed, isNotNull);

      await tester.tap(find.text('Suivant → Montant'));
      await tester.pumpAndSettle();
      expect(capturedSelection?.method, 'STRIPE');
    });

    testWidgets('next_disabledUntilRecognized', (tester) async {
      const typing = PayerAccountState(
        status: PayerAccountStatus.ready,
        countries: kPayerCountries,
        country: kCoteDIvoire,
        operator: kOrangeCiv,
        localNumber: '0748',
        e164: '+2250748',
      );
      // Fermé par le tearDown posé dans payerStarts.
      // ignore: close_sinks
      final states = payerStarts(typing);
      await openMobileMoney(tester);
      expect(cta(tester).onPressed, isNull);

      for (final recognition in [
        RecognitionStatus.checking,
        RecognitionStatus.unrecognized,
        RecognitionStatus.failed,
      ]) {
        states.add(kPayerRecognized.copyWith(recognition: recognition));
        // Jamais pumpAndSettle : l'indicateur de vérification tourne.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(cta(tester).onPressed, isNull, reason: recognition.name);
      }

      states.add(kPayerRecognized);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(cta(tester).onPressed, isNotNull);
    });

    testWidgets('codeTile_stillVisible_andOpensSheet', (tester) async {
      payerStarts(kPayerRecognized);
      await openMobileMoney(tester);

      await tester.ensureVisible(find.text("J'ai un code de recharge"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("J'ai un code de recharge"));
      await tester.pumpAndSettle();

      expect(find.text('Valider le code'), findsOneWidget);
    });

    testWidgets('next_pushesAmountWithOperatorInSelection', (tester) async {
      payerStarts(kPayerRecognized);
      await openMobileMoney(tester);

      final cubit = BlocProvider.of<WalletTopupMobileMoneyCubit>(
        tester.element(find.byType(WalletTopupMethodScreen)),
      );

      await tester.tap(find.text('Suivant → Montant'));
      await tester.pumpAndSettle();

      expect(capturedSelection, isNotNull);
      expect(capturedSelection!.method, 'MOBILE_MONEY');
      expect(capturedSelection!.phoneNumber, '+2250748840856');
      expect(capturedSelection!.currency, 'XOF');
      expect(capturedSelection!.operator, kOrangeCiv);
      expect(capturedSelection!.cubit, same(cubit));

      // L'opérateur choisi est celui que la recharge enverra au back, sans
      // catalogue chargé par l'ancien parcours.
      unawaited(cubit.initiate(amount: 5000, phoneNumber: '+2250748840856'));
      await tester.pump();
      await tester.pump();
      verify(
        () => repo.topupMobileMoney(
          amount: 5000,
          phoneNumber: '+2250748840856',
          provider: 'ORANGE_CIV',
        ),
      ).called(1);
      cubit.stopPolling();
    });

    testWidgets('confirmed_callsRememberSuccess', (tester) async {
      when(
        () => repo.topupStatus(any()),
      ).thenAnswer((_) async => statusFor('CONFIRMED'));
      payerStarts(kPayerRecognized);
      await openMobileMoney(tester);

      final cubit = BlocProvider.of<WalletTopupMobileMoneyCubit>(
        tester.element(find.byType(WalletTopupMethodScreen)),
      );
      verifyNever(() => payer.rememberSuccess());

      unawaited(cubit.initiate(amount: 5000, phoneNumber: '+2250748840856'));
      await tester.pump();
      await tester.pump();
      await tester.pump(WalletTopupMobileMoneyCubit.pollInterval);
      await tester.pump();

      verify(() => payer.rememberSuccess()).called(1);
      await tester.pumpAndSettle();
    });

    testWidgets('moyenRows_keepTheirPlace_whenProbeAnswers', (tester) async {
      final probe = Completer<bool>();
      when(
        () => repo.isMobileMoneyTopupAvailable(),
      ).thenAnswer((_) => probe.future);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      // Sonde en cours : la place de la ligne mobile money est réservée,
      // la carte bancaire reste utilisable.
      expect(
        find.byKey(const ValueKey('MOBILE_MONEY-pending')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('STRIPE')), findsOneWidget);
      final cardTop = tester.getTopLeft(find.text('Carte bancaire')).dy;
      final codeTop = tester
          .getTopLeft(find.text("J'ai un code de recharge"))
          .dy;

      probe.complete(true);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('MOBILE_MONEY')), findsOneWidget);
      expect(find.byKey(const ValueKey('MOBILE_MONEY-pending')), findsNothing);
      expect(tester.getTopLeft(find.text('Carte bancaire')).dy, cardTop);
      expect(
        tester.getTopLeft(find.text("J'ai un code de recharge")).dy,
        codeTop,
      );
      // Laisse jouer l'entrée de la nouvelle ligne (minuteur de départ).
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    });

    testWidgets('methodScreen_darkTheme_rendersWithoutOverflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      payerStarts(
        kPayerRecognized.copyWith(
          operator: kMtnCiv,
          recognition: RecognitionStatus.autoSwitched,
          switchedFrom: 'ORANGE_CIV',
        ),
      );

      await tester.pumpWidget(buildHarness(theme: AppTheme.dark()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text("C'est un numéro MTN MoMo : l'opérateur a été changé."),
        findsOneWidget,
      );
    });

    testWidgets('methodScreen_withPendingTopup_opensAwaitingDirectly', (
      tester,
    ) async {
      when(
        () => repo.pendingTopup(),
      ).thenAnswer((_) async => statusFor('PENDING'));
      when(
        () => repo.topupStatus(any()),
      ).thenAnswer((_) async => statusFor('PENDING'));
      payerStarts(kPayerReady);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      // Plus de 409 « recharge déjà en cours » : l'attente de la recharge
      // ouverte est reprise.
      expect(find.text('Attente'), findsOneWidget);
      final cubit = BlocProvider.of<WalletTopupMobileMoneyCubit>(
        tester.element(
          find.byType(WalletTopupMethodScreen, skipOffstage: false),
        ),
      );
      expect(capturedAwaitingArgs, isNotNull);
      expect(capturedAwaitingArgs!.cubit, same(cubit));
      expect(capturedAwaitingArgs!.amount, 5000);
      // Numéro inconnu en clair (le back ne renvoie que le numéro masqué) :
      // « Renvoyer une demande » ne sera pas proposé.
      expect(capturedAwaitingArgs!.phoneNumber, isNull);
      expect(cubit.state, isA<WalletTopupMobileMoneyAwaiting>());
      cubit.stopPolling();
    });

    testWidgets('aucune recharge en cours : l\'écran 1 reste affiché', (
      tester,
    ) async {
      payerStarts(kPayerReady);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      verify(() => repo.pendingTopup()).called(1);
      expect(find.text('Attente'), findsNothing);
      expect(find.text('Mobile money'), findsOneWidget);
    });

    testWidgets('confirmed_afterResume_doesNotRemember', (tester) async {
      when(
        () => repo.pendingTopup(),
      ).thenAnswer((_) async => statusFor('PENDING'));
      when(
        () => repo.topupStatus(any()),
      ).thenAnswer((_) async => statusFor('CONFIRMED'));
      // Le compte prérempli n'est pas celui de la recharge reprise : il ne
      // doit pas être mémorisé à sa place.
      payerStarts(kPayerRecognized);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      await tester.pump(WalletTopupMobileMoneyCubit.pollInterval);
      await tester.pumpAndSettle();

      final cubit = BlocProvider.of<WalletTopupMobileMoneyCubit>(
        tester.element(
          find.byType(WalletTopupMethodScreen, skipOffstage: false),
        ),
      );
      expect(cubit.state, isA<WalletTopupMobileMoneyConfirmed>());
      verifyNever(() => payer.rememberSuccess());
    });
  });
}
