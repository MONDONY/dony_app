import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_availability_cubit.dart';
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
    when(
      () => repo.isMobileMoneyTopupAvailable(),
    ).thenAnswer((_) async => true);
    when(() => repo.topupProviders(any())).thenAnswer((_) async => catalog);
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
        BlocProvider<WalletTopupMobileMoneyCubit>.value(value: mmCubit),
        BlocProvider<WalletTopupMobileMoneyAvailabilityCubit>(
          create: (_) => WalletTopupMobileMoneyAvailabilityCubit(repo)..probe(),
        ),
      ],
      child: const WalletTopupMethodScreen(),
    );
  }

  Widget buildHarness() {
    final mmCubit = WalletTopupMobileMoneyCubit(
      repo,
      makeEnabledAnalytics(analyticsBackend),
    );
    addTearDown(mmCubit.close);
    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/method',
      routes: [
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
    'CRITIQUE — sortie par le bouton retour de l\'écran d\'attente : écran de '
    'choix pleinement utilisable, plus aucun sondage, confirmation tardive '
    'sans effet',
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
      // Jamais pumpAndSettle() : l'icône pulsée tourne en boucle.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Valide le paiement sur ton téléphone'), findsOneWidget);

      // LE geste corrigé : le bouton retour de l'AppBar, pas « Payer avec un
      // autre numéro ».
      await tester.tap(
        find.descendant(
          of: find.byType(WalletTopupMobileMoneyAwaitingScreen),
          matching: find.byType(DonyAppBarBackButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(WalletTopupMethodScreen), findsOneWidget);
      expect(cubit.state, isA<WalletTopupMobileMoneyProvidersReady>());
      // Le catalogue est rechargé tout seul : l'écran est utilisable sans
      // devoir ressaisir quoi que ce soit.
      verify(() => repo.topupProviders('+221771234567')).called(2);
      expect(find.byKey(const Key('network-ORANGE_SEN')), findsOneWidget);
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNotNull,
      );

      // Plus aucun sondage : la réponse tardive du dépôt abandonné n'a plus
      // d'effet, et aucun tick supplémentaire ne part.
      slowStatus.complete(statusFor('CONFIRMED'));
      await tester.pump();
      expect(cubit.state, isNot(isA<WalletTopupMobileMoneyConfirmed>()));
      await tester.pump(WalletTopupMobileMoneyCubit.pollInterval);
      // Un seul sondage au total : celui parti avant le retour arrière.
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
}
