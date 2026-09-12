import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/presentation/screens/mobile_money_awaiting_screen.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockBloc extends Mock implements MobileMoneyPaymentBloc {}

class _MockUrlLauncher extends Mock implements ExternalUrlLauncher {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBloc bloc;
  late _MockUrlLauncher urlLauncher;
  late MockAnalyticsBackend analyticsBackend;

  const bidId = 'bid-1';
  const threadId = 'thread-1';
  const scope = MobileMoneyScope.bid(bidId);
  // AppTheme.light() charge des polices via HTTP (google_fonts) : appelée
  // hors d'un testWidgets, la requête tombe hors de la zone de test et
  // plante. On ne la calcule donc jamais au niveau de main(), seulement à
  // l'intérieur des deux tests qui en ont besoin, une fois le binding de
  // test réellement actif.
  final countdownFinder = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.data != null &&
        RegExp(r'^Temps restant \d{2}:\d{2}$').hasMatch(w.data!),
  );

  const awaitingPinStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 50.0,
    deposit: MobileMoneyDeposit(
      id: 'deposit-1',
      status: MobileMoneyDepositStatus.accepted,
      providerLabel: 'Orange Money',
      msisdnMasked: '+225 ** ** ** 12',
    ),
  );

  const awaitingPinNoProviderStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 50.0,
    deposit: MobileMoneyDeposit(
      id: 'deposit-1',
      status: MobileMoneyDepositStatus.accepted,
    ),
  );

  const awaitingWaveStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 50.0,
    deposit: MobileMoneyDeposit(
      id: 'deposit-1',
      status: MobileMoneyDepositStatus.accepted,
      providerLabel: 'Wave',
      authorizationUrl: 'https://pay.wave.com/abc123',
    ),
  );

  const expiredStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    amount: 50.0,
  );

  const depositFailedStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    amount: 50.0,
    deposit: MobileMoneyDeposit(
      id: 'deposit-2',
      status: MobileMoneyDepositStatus.failed,
      failureMessage: 'Solde insuffisant',
    ),
  );

  const depositFailedNoMessageStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    amount: 50.0,
    deposit: MobileMoneyDeposit(
      id: 'deposit-3',
      status: MobileMoneyDepositStatus.submitRejected,
    ),
  );

  const escrowedStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'ACCEPTED',
    paymentStatus: 'ESCROW',
    amount: 50.0,
  );

  const noDepositStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 12500,
  );

  const catalog = MobileMoneyProviderCatalog(
    country: 'CI',
    currency: 'XOF',
    msisdnMasked: '+225 •••• 77',
    detected: 'ORANGE_CIV',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_CIV',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave'),
    ],
    travelerAccepts: ['Orange Money', 'Wave'],
    travelerFirstName: 'Aminata',
  );

  const emptyCatalog = MobileMoneyProviderCatalog(
    country: 'BJ',
    currency: 'XOF',
    msisdnMasked: '+229 •••• 56',
    travelerAccepts: ['Orange Money', 'Wave'],
    travelerFirstName: 'Aminata',
  );

  setUpAll(() {
    // MobileMoneyPaymentEvent est sealed : le fallback est un vrai événement.
    registerFallbackValue(
      const MobileMoneyPaymentOpened(scope: MobileMoneyScope.bid(bidId)),
    );
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);

    urlLauncher = _MockUrlLauncher();
    when(() => urlLauncher.open(any())).thenAnswer((_) async => true);

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    // `onConfigured()` est indispensable : sans lui, `isEnabled` reste faux
    // et `logEvent` n'atteint jamais le backend (rien à vérifier).
    analyticsBackend = MockAnalyticsBackend();
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(analyticsBackend)..onConfigured(),
    );

    if (getIt.isRegistered<ExternalUrlLauncher>()) {
      getIt.unregister<ExternalUrlLauncher>();
    }
    getIt.registerSingleton<ExternalUrlLauncher>(urlLauncher);

    // Le dédoublonnage du snackbar est un état STATIQUE partagé entre tous
    // les tests du process : sans ce reset, un test peut ne pas voir son
    // propre snackbar parce qu'un test précédent a affiché le même message
    // il y a moins de 400 ms (temps réel, pas simulé).
    DonySnackbar.clearDedup();
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<ExternalUrlLauncher>()) {
      getIt.unregister<ExternalUrlLauncher>();
    }
  });

  /// [state] est ce que renvoie le bloc mocké au premier rendu synchrone
  /// (`bloc.state`) ET ce que rejoue son flux. [previous] simule l'état que
  /// le bloc aurait porté juste avant : indispensable pour que le
  /// `listenWhen: (prev, curr) => prev.runtimeType != curr.runtimeType` de
  /// l'écran laisse passer le `listener` (sinon prev == curr et rien ne se
  /// déclenche jamais dans ces tests).
  void stub(
    MobileMoneyPaymentState state, {
    MobileMoneyPaymentState previous = const MobileMoneyPaymentLoading(),
  }) {
    when(() => bloc.state).thenReturn(previous);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<MobileMoneyPaymentState>.value(state));
  }

  late Future<bool?> poppedResult;

  /// Monte l'écran poussé (`push<bool>`) par-dessus un écran hôte factice,
  /// pour pouvoir observer à la fois la navigation retour ET la valeur
  /// exacte renvoyée par `context.pop(...)` (comme le fait réellement
  /// `BidDetailScreen` via `await context.push<bool>(...)`).
  ///
  /// [settle] reste faux dès qu'un `Timer` périodique tourne encore sans
  /// jamais s'arrêter (spinner indéterminé, ou compte à rebours actif tant
  /// que `deadlineAt` est fourni) : ces cas feraient expirer `pumpAndSettle`.
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool settle = true,
    MobileMoneyScope scope = const MobileMoneyScope.bid(bidId),
    String? initialPhone,
  }) async {
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (_, _) => const Scaffold(body: Text('host')),
        ),
        GoRoute(
          path: '/awaiting',
          builder: (_, _) => BlocProvider<MobileMoneyPaymentBloc>.value(
            value: bloc,
            child: MobileMoneyAwaitingScreen(
              scope: scope,
              initialPhone: initialPhone,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    final hostContext = tester.element(find.text('host'));
    poppedResult = hostContext.push<bool>('/awaiting');
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Une frame pour que le routeur matérialise le push (nouvelle page
      // ajoutée au Navigator), puis une frame à durée explicite pour que la
      // transition se termine — jamais pumpAndSettle ici, qui boucle
      // indéfiniment sur le spinner indéterminé ou le compte à rebours actif
      // de la page de destination.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('état initial : indicateur de chargement', (tester) async {
    stub(
      const MobileMoneyPaymentInitial(),
      previous: const MobileMoneyPaymentInitial(),
    );

    await pumpScreen(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Paiement mobile money'), findsOneWidget);
  });

  testWidgets('ouverture : le statut est demandé immédiatement', (
    tester,
  ) async {
    stub(
      const MobileMoneyPaymentInitial(),
      previous: const MobileMoneyPaymentInitial(),
    );

    await pumpScreen(tester, settle: false);

    // Ne pas attendre le premier tick de 5 s pour savoir où en est le
    // paiement : l'ouverture de l'écran déclenche Opened, pas un simple
    // sondage (Opened peut initier un premier dépôt si aucun n'existe).
    verify(
      () => bloc.add(any(that: isA<MobileMoneyPaymentOpened>())),
    ).called(1);
  });

  group('analytics mobileMoneyAwaiting', () {
    testWidgets('porte scope bid en portée bid', (tester) async {
      stub(
        const MobileMoneyPaymentInitial(),
        previous: const MobileMoneyPaymentInitial(),
      );

      await pumpScreen(tester, settle: false);

      verify(
        () => analyticsBackend.capture(AnalyticsEvents.mobileMoneyAwaiting, {
          'provider': 'mobile_money',
          'scope': 'bid',
        }),
      ).called(1);
    });

    testWidgets('porte scope negotiation en portée négociation', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentInitial(),
        previous: const MobileMoneyPaymentInitial(),
      );

      await pumpScreen(
        tester,
        settle: false,
        scope: const MobileMoneyScope.negotiation(threadId),
      );

      verify(
        () => analyticsBackend.capture(AnalyticsEvents.mobileMoneyAwaiting, {
          'provider': 'mobile_money',
          'scope': 'negotiation',
        }),
      ).called(1);
    });
  });

  testWidgets('sondage : un event Polled est envoyé toutes les 5 secondes', (
    tester,
  ) async {
    stub(const MobileMoneyPaymentAwaitingConfirmation(awaitingPinStatus));

    await pumpScreen(tester, settle: false);
    await tester.pump(const Duration(seconds: 5));

    verify(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>()))).called(1);
  });

  group('Zone sûre', () {
    testWidgets('le corps est protégé de la barre de navigation système', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentInitial());
      await pumpScreen(tester, settle: false);
      await tester.pump();
      // L'AppBar porte sa propre SafeArea (haut seulement) : on cible celle
      // du corps, qui protège le bouton bas de la barre de navigation.
      expect(
        find.byWidgetPredicate(
          (w) => w is SafeArea && !w.top && w.bottom,
          description: 'SafeArea du corps (bas seulement)',
        ),
        findsOneWidget,
      );
    });
  });

  group('AwaitingConfirmation — PIN opérateur', () {
    testWidgets(
      'affiche le montant, l\'opérateur, le numéro masqué et le texte PIN',
      (tester) async {
        stub(const MobileMoneyPaymentAwaitingConfirmation(awaitingPinStatus));

        await pumpScreen(tester);

        expect(find.textContaining('Orange Money'), findsWidgets);
        expect(find.text('+225 ** ** ** 12'), findsOneWidget);
        expect(
          find.text(
            'Valide le paiement sur ton téléphone : une demande de code PIN '
            "vient de t'être envoyée par Orange Money.",
          ),
          findsOneWidget,
        );
        expect(
          find.text('La confirmation est automatique, garde cet écran ouvert.'),
          findsOneWidget,
        );
        expect(find.text('Ouvrir Wave'), findsNothing);
      },
    );

    testWidgets('providerLabel nul → repli "ton opérateur"', (tester) async {
      stub(
        const MobileMoneyPaymentAwaitingConfirmation(
          awaitingPinNoProviderStatus,
        ),
      );

      await pumpScreen(tester);

      expect(
        find.text(
          'Valide le paiement sur ton téléphone : une demande de code PIN '
          "vient de t'être envoyée par ton opérateur.",
        ),
        findsOneWidget,
      );
    });
  });

  group('AwaitingConfirmation — Wave', () {
    testWidgets('affiche le texte Wave et le bouton Ouvrir Wave', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentAwaitingConfirmation(awaitingWaveStatus));

      await pumpScreen(tester);

      expect(
        find.text("Termine le paiement dans l'application Wave"),
        findsOneWidget,
      );
      expect(find.text('Ouvrir Wave'), findsOneWidget);
      expect(find.textContaining('code PIN'), findsNothing);
    });

    testWidgets(
      'Ouvrir Wave ouvre l\'authorizationUrl via ExternalUrlLauncher',
      (tester) async {
        stub(const MobileMoneyPaymentAwaitingConfirmation(awaitingWaveStatus));

        await pumpScreen(tester);
        await tester.tap(find.text('Ouvrir Wave'));
        await tester.pump();

        verify(
          () => urlLauncher.open(Uri.parse('https://pay.wave.com/abc123')),
        ).called(1);
      },
    );
  });

  group('Compte à rebours', () {
    testWidgets('affiché et rouge sous 5 minutes', (tester) async {
      final deadline = DateTime.now().toUtc().add(const Duration(minutes: 4));
      stub(
        MobileMoneyPaymentAwaitingConfirmation(
          MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            amount: 50.0,
            deadlineAt: deadline,
            deposit: awaitingPinStatus.deposit,
          ),
        ),
      );

      await pumpScreen(tester, settle: false);

      expect(countdownFinder, findsOneWidget);
      final style = tester.widget<Text>(countdownFinder).style;
      expect(style?.color, AppTheme.light().colorScheme.error);
    });

    testWidgets('affiché mais pas rouge loin de l\'échéance', (tester) async {
      final deadline = DateTime.now().toUtc().add(const Duration(minutes: 20));
      stub(
        MobileMoneyPaymentAwaitingConfirmation(
          MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            amount: 50.0,
            deadlineAt: deadline,
            deposit: awaitingPinStatus.deposit,
          ),
        ),
      );

      await pumpScreen(tester, settle: false);

      expect(countdownFinder, findsOneWidget);
      final style = tester.widget<Text>(countdownFinder).style;
      expect(style?.color, AppTheme.light().colorScheme.onSurfaceVariant);
    });

    testWidgets('deadlineAt nul → aucun compte à rebours affiché', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentAwaitingConfirmation(awaitingPinStatus));

      await pumpScreen(tester);

      expect(countdownFinder, findsNothing);
    });

    testWidgets('reste affiché quand le dépôt a échoué (relance possible)', (
      tester,
    ) async {
      final deadline = DateTime.now().toUtc().add(const Duration(minutes: 4));
      stub(
        MobileMoneyPaymentDepositFailed(
          MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            amount: 50.0,
            deadlineAt: deadline,
            deposit: depositFailedStatus.deposit,
          ),
        ),
      );

      await pumpScreen(tester, settle: false);

      expect(countdownFinder, findsOneWidget);
    });
  });

  group('DepositFailed', () {
    testWidgets('message du backend affiché, relance avec le numéro saisi', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentDepositFailed(depositFailedStatus));

      await pumpScreen(tester);

      expect(find.text('Solde insuffisant'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mobile-money-retry-phone-field')),
        '06 12 34 56 78',
      );
      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      // Depuis un dépôt refusé, « Réessayer » ramène désormais au choix de
      // l'opérateur (ProvidersRequested) plutôt que de relancer aveuglément
      // le même opérateur (InitiateRequested) : voir group('choix de
      // l\'opérateur') pour le cas sans numéro saisi.
      verify(
        () => bloc.add(
          const MobileMoneyPaymentProvidersRequested(
            scope: MobileMoneyScope.bid(bidId),
            phoneNumber: '0612345678',
          ),
        ),
      ).called(1);
    });

    testWidgets('sans message backend : repli "Le paiement a été refusé par '
        'l\'opérateur"', (tester) async {
      stub(const MobileMoneyPaymentDepositFailed(depositFailedNoMessageStatus));

      await pumpScreen(tester);

      expect(
        find.text("Le paiement a été refusé par l'opérateur"),
        findsOneWidget,
      );
    });

    testWidgets(
      'le sondage est arrêté : plus aucun event Polled après coup (le '
      'compte à rebours, lui, continue)',
      (tester) async {
        stub(const MobileMoneyPaymentDepositFailed(depositFailedStatus));

        await pumpScreen(tester);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));

        // Comme pour Escrowed : verifyNever, pas called(0) (mocktail échoue
        // sur called(0) avec "No matching calls").
        verifyNever(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>())));
      },
    );
  });

  group('choix de l\'opérateur', () {
    // Calculé via formatPriceIn (comme l'écran) plutôt que codé en dur :
    // NumberFormat sépare les milliers par une espace fine insécable
    // (U+202F), pas une espace classique — un littéral tapé à la main ne
    // matcherait jamais le texte réellement rendu.
    final payAmountLabel =
        'Payer ${formatPriceIn(noDepositStatus.amount ?? 0, noDepositStatus.currency)}';

    testWidgets(
      'affiche montant, numéro masqué, réseaux, note et bouton payer',
      (tester) async {
        stub(
          const MobileMoneyPaymentChooseOperator(
            status: noDepositStatus,
            catalog: catalog,
          ),
        );

        await pumpScreen(tester);

        expect(find.text('Avec quel opérateur ?'), findsOneWidget);
        expect(find.text('+225 •••• 77'), findsOneWidget);
        expect(find.text('Orange Money'), findsOneWidget);
        expect(find.text('Wave'), findsOneWidget);
        expect(find.text('Détecté pour ce numéro'), findsOneWidget);
        expect(
          find.textContaining('Aminata accepte Orange Money et Wave'),
          findsOneWidget,
        );
        expect(find.widgetWithText(DonyButton, payAmountLabel), findsOneWidget);
      },
    );

    testWidgets(
      'payer envoie l\'initiation avec l\'opérateur détecté par défaut',
      (tester) async {
        stub(
          const MobileMoneyPaymentChooseOperator(
            status: noDepositStatus,
            catalog: catalog,
          ),
        );

        await pumpScreen(tester);
        await tester.tap(find.widgetWithText(DonyButton, payAmountLabel));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyPaymentInitiateRequested(
              scope: scope,
              provider: 'ORANGE_CIV',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('choisir Wave puis payer envoie WAVE_CIV', (tester) async {
      stub(
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          catalog: catalog,
        ),
      );

      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('operator-WAVE_CIV')));
      await tester.pump();
      await tester.tap(find.widgetWithText(DonyButton, payAmountLabel));
      await tester.pump();

      verify(
        () => bloc.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            provider: 'WAVE_CIV',
          ),
        ),
      ).called(1);
    });

    testWidgets('saisir un autre numéro recharge le catalogue après le délai', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          catalog: catalog,
        ),
      );

      await pumpScreen(tester);
      await tester.enterText(
        find.byKey(const Key('mobile-money-payer-phone-field')),
        '+229 01 97 12 34 56',
      );
      await tester.pump(const Duration(milliseconds: 450));

      verify(
        () => bloc.add(
          const MobileMoneyPaymentProvidersRequested(
            scope: scope,
            phoneNumber: '+2290197123456',
          ),
        ),
      ).called(1);
    });

    testWidgets('aucun réseau commun : bandeau explicite, bouton désactivé', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          catalog: emptyCatalog,
        ),
      );

      await pumpScreen(tester);

      expect(
        find.textContaining("qui n'existent pas pour ton numéro (Bénin)"),
        findsOneWidget,
      );
      final button = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, payAmountLabel),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('catalogue en chargement : squelette', (tester) async {
      stub(
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          isLoadingCatalog: true,
        ),
      );

      await pumpScreen(tester, settle: false);
      await tester.pump();

      expect(find.byType(MobileMoneyNetworksSkeleton), findsOneWidget);
    });

    testWidgets(
      'bandeau d\'erreur : « Réessayer » relance le catalogue avec le même '
      'numéro',
      (tester) async {
        stub(
          const MobileMoneyPaymentChooseOperator(
            status: noDepositStatus,
            payerPhone: '+221771234567',
            error: NetworkException('boom'),
          ),
        );

        await pumpScreen(tester);
        await tester.tap(find.text('Réessayer'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyPaymentProvidersRequested(
              scope: scope,
              phoneNumber: '+221771234567',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'bandeau d\'erreur sans numéro saisi : « Réessayer » relance sans '
      'numéro',
      (tester) async {
        stub(
          const MobileMoneyPaymentChooseOperator(
            status: noDepositStatus,
            error: NetworkException('boom'),
          ),
        );

        await pumpScreen(tester);
        await tester.tap(find.text('Réessayer'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyPaymentProvidersRequested(scope: scope),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'dépôt refusé : « Réessayer » ramène au choix de l\'opérateur',
      (tester) async {
        stub(const MobileMoneyPaymentDepositFailed(depositFailedStatus));

        await pumpScreen(tester);
        await tester.tap(find.text('Réessayer'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyPaymentProvidersRequested(scope: scope),
          ),
        ).called(1);
      },
    );
  });

  /// Ouvert depuis la push « paiement en attente » (lien profond), l'écran
  /// est la seule page de la pile : rien à dépiler, le repli est le détail du
  /// colis (Sentry FLUTTER-1D, « There is nothing to pop »).
  Future<void> pumpDeepLinked(
    WidgetTester tester, {
    MobileMoneyScope scope = const MobileMoneyScope.bid(bidId),
  }) async {
    final router = GoRouter(
      initialLocation: scope.awaitingRoute,
      routes: [
        GoRoute(
          path: '/bids/:bidId',
          builder: (_, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['bidId']}')),
        ),
        GoRoute(
          path: '/negotiations/:id',
          builder: (_, state) =>
              Scaffold(body: Text('thread ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/bids/:bidId/mobile-money/awaiting',
          builder: (_, _) => BlocProvider<MobileMoneyPaymentBloc>.value(
            value: bloc,
            child: MobileMoneyAwaitingScreen(scope: scope),
          ),
        ),
        GoRoute(
          path: '/negotiations/:id/mobile-money/awaiting',
          builder: (_, _) => BlocProvider<MobileMoneyPaymentBloc>.value(
            value: bloc,
            child: MobileMoneyAwaitingScreen(scope: scope),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  group('Ouvert par lien profond (pile vide)', () {
    testWidgets('Escrowed → détail du colis, sans « nothing to pop »', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpDeepLinked(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('detail $bidId'), findsOneWidget);
    });

    testWidgets('Expired + Retour → détail du colis', (tester) async {
      stub(const MobileMoneyPaymentExpired(expiredStatus));

      await pumpDeepLinked(tester);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('detail $bidId'), findsOneWidget);
    });
  });

  group('Portée négociation', () {
    testWidgets('Escrowed sans pile (lien profond) → fil de négociation, sans '
        '« nothing to pop »', (tester) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpDeepLinked(
        tester,
        scope: const MobileMoneyScope.negotiation(threadId),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('thread $threadId'), findsOneWidget);
    });

    testWidgets('ouverture avec initialPhone : le bloc reçoit '
        'MobileMoneyPaymentOpened(scope, phoneNumber)', (tester) async {
      const scope = MobileMoneyScope.negotiation(threadId);
      stub(
        const MobileMoneyPaymentInitial(),
        previous: const MobileMoneyPaymentInitial(),
      );

      await pumpScreen(
        tester,
        settle: false,
        scope: scope,
        initialPhone: '+221771234567',
      );

      verify(
        () => bloc.add(
          const MobileMoneyPaymentOpened(
            scope: scope,
            phoneNumber: '+221771234567',
          ),
        ),
      ).called(1);
    });
  });

  group('Expired', () {
    testWidgets('texte + bouton Retour → pop(false)', (tester) async {
      stub(const MobileMoneyPaymentExpired(expiredStatus));

      await pumpScreen(tester);

      expect(
        find.text(
          'Délai dépassé. La demande a été annulée, refais une offre au '
          'voyageur.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('host'), findsOneWidget);
      expect(await poppedResult, isFalse);
    });

    testWidgets(
      'en portée négociation : le fil est revenu à « à payer », pas de '
      'demande annulée',
      (tester) async {
        stub(
          const MobileMoneyPaymentExpired(
            MobileMoneyPaymentStatus(
              subjectId: threadId,
              paymentStatus: 'CANCELLED',
              amount: 50.0,
            ),
          ),
        );

        await pumpScreen(
          tester,
          scope: const MobileMoneyScope.negotiation(threadId),
        );

        expect(
          find.text(
            'Délai dépassé. Le fil est revenu à « à payer » : tu peux '
            'relancer le paiement ou changer de moyen de paiement depuis le '
            'fil.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('La demande a été annulée'), findsNothing);

        await tester.tap(find.text('Retour'));
        await tester.pumpAndSettle();

        expect(find.text('host'), findsOneWidget);
        expect(await poppedResult, isFalse);
      },
    );
  });

  group('Escrowed', () {
    testWidgets('snackbar succès puis pop(true) vers l\'appelant', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpScreen(tester);

      expect(find.text('host'), findsOneWidget);
      expect(
        find.text('Paiement confirmé, ton envoi est sécurisé'),
        findsOneWidget,
      );
      expect(await poppedResult, isTrue);
    });

    testWidgets('les timers sont annulés : plus aucun sondage après coup', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 6));

      // verify(...).called(0) échoue toujours chez mocktail ("No matching
      // calls") : c'est verifyNever qu'il faut pour affirmer zéro appel.
      verifyNever(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>())));
    });
  });

  group('Error', () {
    testWidgets(
      'message générique (jamais le détail brut), réessai relance l\'ouverture',
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
  });

  // Le compte Firebase de l'expéditeur peut n'avoir aucun téléphone tant que
  // la vérification SMS (Twilio) n'est pas configurée : le backend renvoie
  // alors ce code sur l'initiation, sans numéro de repli possible (contraire
  // au groupe DepositFailed, où le numéro reste facultatif).
  group('Error — numéro manquant (mobile-money-phone-required)', () {
    testWidgets(
      'corps dédié avec champ numéro ; bouton inactif sans numéro valide, '
      'relance avec le numéro normalisé sinon',
      (tester) async {
        stub(
          const MobileMoneyPaymentError(
            ValidationException(
              'Aucun numéro disponible',
              code: 'mobile-money-phone-required',
            ),
          ),
        );

        await pumpScreen(tester);

        expect(
          find.text(
            "Ton compte Yadony n'a pas de numéro de téléphone : indique "
            'le numéro mobile money qui paiera.',
          ),
          findsOneWidget,
        );
        // Le DonyEmptyState générique n'apparaît pas pour ce cas dédié.
        expect(find.text('Une erreur est survenue'), findsNothing);

        final button = tester.widget<DonyButton>(find.byType(DonyButton));
        expect(button.onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('mobile-money-phone-required-field')),
          '+221 77 345 67 89',
        );
        await tester.pump();

        final buttonAfter = tester.widget<DonyButton>(find.byType(DonyButton));
        expect(buttonAfter.onPressed, isNotNull);

        await tester.tap(find.text('Réessayer'));
        await tester.pump();

        verify(
          () => bloc.add(
            const MobileMoneyPaymentInitiateRequested(
              scope: MobileMoneyScope.bid(bidId),
              phoneNumber: '+221773456789',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'un autre code métier (mobile-money-disabled) garde le DonyEmptyState '
      'générique, jamais le corps dédié',
      (tester) async {
        stub(
          const MobileMoneyPaymentError(
            ValidationException(
              'Le mobile money est désactivé pour ce pays',
              code: 'mobile-money-disabled',
            ),
          ),
        );

        await pumpScreen(tester);

        expect(find.text('Une erreur est survenue'), findsOneWidget);
        expect(
          find.byKey(const Key('mobile-money-phone-required-field')),
          findsNothing,
        );
      },
    );
  });
}
