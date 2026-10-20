import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/presentation/screens/mobile_money_awaiting_screen.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';
import '../../../../helpers/payer_account_test_doubles.dart';

class _MockBloc extends Mock implements MobileMoneyPaymentBloc {}

class _MockUrlLauncher extends Mock implements ExternalUrlLauncher {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

class _MockBox extends Mock implements Box {}

/// [HiveService.userPrefs] ouvre une vraie box Hive : remplacée par un mock
/// pour que `requirePaymentAuth` ne touche pas au disque.
class _FakeHiveService extends HiveService {
  _FakeHiveService(this._box);
  final Box _box;

  @override
  Box get userPrefs => _box;
}

/// Écran « Payer le colis » (bid, fil de négociation, supplément) : étape
/// « Qui paie ? » sur le composant partagé, attente dans le panneau partagé,
/// « Pas encore validé », échec traduit, expiration, séquestre.
///
/// L'anneau d'attente et le compte à rebours tournent en boucle : jamais de
/// `pumpAndSettle()` tant qu'ils sont montés, des `pump()` bornés.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBloc bloc;
  late MockPayerAccountCubit payerCubit;
  late _MockUrlLauncher urlLauncher;
  late _MockLocalAuthService authService;
  late _MockBox userPrefsBox;
  late MockAnalyticsBackend analyticsBackend;
  late StreamController<PayerAccountState> payerController;
  final payerControllers = <StreamController<PayerAccountState>>[];

  void resetRegistration<T extends Object>() {
    if (getIt.isRegistered<T>()) getIt.unregister<T>();
  }

  /// Branche le composant « compte qui paie » sur [state] ; le contrôleur
  /// rendu permet de pousser d'autres états et se ferme en fin de test.
  StreamController<PayerAccountState> payerOn(PayerAccountState state) {
    final controller = stubPayerAccount(payerCubit, state);
    payerControllers.add(controller);
    return payerController = controller;
  }

  const bidId = 'bid-1';
  const threadId = 'thread-1';
  const scope = MobileMoneyScope.bid(bidId);
  const supplementScope = MobileMoneyScope.supplement(
    bidId: bidId,
    supplementId: 'sup-1',
  );

  final countdownFinder = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.data != null &&
        RegExp(r'^Temps restant \d{2}:\d{2}$').hasMatch(w.data!),
  );

  final payLabel = 'Payer ${formatPriceIn(12500, 'XOF')}';

  const noDepositStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 12500,
  );

  MobileMoneyPaymentStatus awaitingStatus({
    MobileMoneyValidationHint hint = MobileMoneyValidationHint.smsLink,
    String? providerLabel = 'Orange Money',
    String? msisdnMasked = '+225 07 •• •• 56',
    String? authorizationUrl,
    DateTime? deadlineAt,
  }) => MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 12500,
    deadlineAt: deadlineAt ?? DateTime.now().toUtc().add(_fifteenMinutes),
    deposit: MobileMoneyDeposit(
      id: 'deposit-1',
      status: MobileMoneyDepositStatus.accepted,
      provider: 'ORANGE_CIV',
      providerLabel: providerLabel,
      msisdnMasked: msisdnMasked,
      authorizationUrl: authorizationUrl,
      validationHint: hint,
    ),
  );

  MobileMoneyPaymentStatus failedStatus({
    String? code,
    String? message,
    MobileMoneyDepositStatus status = MobileMoneyDepositStatus.failed,
  }) => MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    amount: 12500,
    deadlineAt: DateTime.now().toUtc().add(_fifteenMinutes),
    deposit: MobileMoneyDeposit(
      id: 'deposit-2',
      status: status,
      failureReasonCode: code,
      failureMessage: message,
    ),
  );

  const expiredStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    amount: 50.0,
  );

  const escrowedStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'ACCEPTED',
    paymentStatus: 'ESCROW',
    amount: 12500,
  );

  const acceptedOrangeOnly = MobileMoneyAcceptedOperators(
    currency: 'XOF',
    travelerFirstName: 'Awa',
    providers: {'ORANGE_CIV'},
  );

  setUpAll(() {
    // MobileMoneyPaymentEvent est sealed : le fallback est un vrai événement.
    registerFallbackValue(const MobileMoneyPaymentOpened(scope: scope));
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
    when(() => bloc.canResend).thenReturn(true);

    payerCubit = MockPayerAccountCubit();
    payerOn(kPayerRecognized);
    when(
      () => payerCubit.configure(
        currency: any(named: 'currency'),
        allowedOperators: any(named: 'allowedOperators'),
      ),
    ).thenAnswer((_) async {});
    when(() => payerCubit.restrictOperators(any())).thenReturn(null);

    urlLauncher = _MockUrlLauncher();
    when(() => urlLauncher.open(any())).thenAnswer((_) async => true);

    // Par défaut : ni biométrie ni PIN, `requirePaymentAuth` laisse passer.
    authService = _MockLocalAuthService();
    userPrefsBox = _MockBox();
    when(
      () => userPrefsBox.get(
        HiveService.kBiometricEnabled,
        defaultValue: any(named: 'defaultValue'),
      ),
    ).thenReturn(false);
    when(() => authService.isPinSet()).thenAnswer((_) async => false);

    resetRegistration<AnalyticsService>();
    resetRegistration<ExternalUrlLauncher>();
    resetRegistration<LocalAuthService>();
    resetRegistration<HiveService>();
    // `onConfigured()` est indispensable : sans lui, `isEnabled` reste faux
    // et `logEvent` n'atteint jamais le backend (rien à vérifier).
    analyticsBackend = MockAnalyticsBackend();
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(analyticsBackend)..onConfigured(),
    );
    getIt.registerSingleton<ExternalUrlLauncher>(urlLauncher);
    getIt.registerSingleton<LocalAuthService>(authService);
    getIt.registerSingleton<HiveService>(_FakeHiveService(userPrefsBox));

    // Le dédoublonnage du snackbar est un état STATIQUE partagé entre tous
    // les tests du process : sans ce reset, un test peut ne pas voir son
    // propre snackbar parce qu'un test précédent a affiché le même message
    // il y a moins de 400 ms (temps réel, pas simulé).
    DonySnackbar.clearDedup();
  });

  tearDown(() async {
    for (final controller in payerControllers) {
      await controller.close();
    }
    payerControllers.clear();
    resetRegistration<AnalyticsService>();
    resetRegistration<ExternalUrlLauncher>();
    resetRegistration<LocalAuthService>();
    resetRegistration<HiveService>();
  });

  /// [state] est ce que renvoie le bloc mocké au premier rendu synchrone
  /// (`bloc.state`) ET ce que rejoue son flux. [previous] simule l'état que
  /// le bloc aurait porté juste avant : indispensable pour que le
  /// `listenWhen: (prev, curr) => prev.runtimeType != curr.runtimeType` de
  /// l'écran laisse passer le `listener`.
  void stub(
    MobileMoneyPaymentState state, {
    MobileMoneyPaymentState previous = const MobileMoneyPaymentLoading(),
  }) {
    when(() => bloc.state).thenReturn(previous);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<MobileMoneyPaymentState>.value(state));
  }

  /// Bloc piloté à la main : chaque `emit` met à jour `bloc.state` puis pousse
  /// le nouvel état dans le flux, comme un vrai bloc.
  void Function(MobileMoneyPaymentState) drive(
    MobileMoneyPaymentState initial,
    StreamController<MobileMoneyPaymentState> controller,
  ) {
    var current = initial;
    when(() => bloc.state).thenAnswer((_) => current);
    when(() => bloc.stream).thenAnswer((_) => controller.stream);
    return (next) {
      current = next;
      controller.add(next);
    };
  }

  /// Laisse partir la minuterie à zéro seconde de `flutter_animate` (apparition
  /// des lignes du composant), créée pendant la dernière image : sans cette
  /// image de plus, elle serait encore en attente à la fin du test.
  Future<void> settleMotion(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 400));
  }

  late Future<bool?> poppedResult;

  /// Monte l'écran poussé (`push<bool>`) par-dessus un écran hôte factice,
  /// pour observer à la fois la navigation retour ET la valeur exacte
  /// renvoyée par `context.pop(...)`. Le PIN de `requirePaymentAuth` est une
  /// route `/auth/local` dont « Refuser le PIN » rend `false`.
  Future<void> pumpScreen(
    WidgetTester tester, {
    MobileMoneyScope scope = scope,
    String? initialPhone,
    ThemeData? theme,
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
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<MobileMoneyPaymentBloc>.value(value: bloc),
              BlocProvider<PayerAccountCubit>.value(value: payerCubit),
            ],
            child: MobileMoneyAwaitingScreen(
              scope: scope,
              initialPhone: initialPhone,
            ),
          ),
        ),
        GoRoute(
          path: '/auth/local',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Refuser le PIN'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: theme ?? AppTheme.light(),
        routerConfig: router,
      ),
    );
    final hostContext = tester.element(find.text('host'));
    poppedResult = hostContext.push<bool>('/awaiting');
    // Une frame pour que le routeur matérialise le push, puis une frame à
    // durée explicite pour que la transition se termine : jamais
    // pumpAndSettle ici (anneau et compte à rebours bouclent).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settleMotion(tester);
  }

  Finder payButton() => find.widgetWithText(DonyButton, payLabel);

  /// Ouvert depuis la push « paiement en attente » (lien profond), l'écran
  /// est la seule page de la pile : rien à dépiler, le repli est le détail du
  /// colis (Sentry FLUTTER-1D, « There is nothing to pop »).
  Future<void> pumpDeepLinked(
    WidgetTester tester, {
    MobileMoneyScope scope = scope,
  }) async {
    Widget page() => MultiBlocProvider(
      providers: [
        BlocProvider<MobileMoneyPaymentBloc>.value(value: bloc),
        BlocProvider<PayerAccountCubit>.value(value: payerCubit),
      ],
      child: MobileMoneyAwaitingScreen(scope: scope),
    );
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
          builder: (_, _) => page(),
        ),
        GoRoute(
          path: '/negotiations/:id/mobile-money/awaiting',
          builder: (_, _) => page(),
        ),
        GoRoute(
          path: '/bids/:bidId/supplements/:supplementId/mobile-money/awaiting',
          builder: (_, _) => page(),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('ouverture', () {
    testWidgets('initial_showsSpinner_andRequestsStatus', (tester) async {
      stub(
        const MobileMoneyPaymentInitial(),
        previous: const MobileMoneyPaymentInitial(),
      );

      await pumpScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Payer le colis'), findsOneWidget);
      // L'ouverture déclenche Opened, pas un simple sondage : Opened décide
      // entre reprendre un dépôt et afficher « Qui paie ? ».
      verify(
        () => bloc.add(const MobileMoneyPaymentOpened(scope: scope)),
      ).called(1);
    });

    testWidgets('initialPhone_isIgnored', (tester) async {
      stub(
        const MobileMoneyPaymentInitial(),
        previous: const MobileMoneyPaymentInitial(),
      );

      await pumpScreen(tester, initialPhone: '+221771234567');

      verify(
        () => bloc.add(const MobileMoneyPaymentOpened(scope: scope)),
      ).called(1);
    });

    testWidgets('body_isProtectedFromSystemNavigationBar', (tester) async {
      stub(
        const MobileMoneyPaymentInitial(),
        previous: const MobileMoneyPaymentInitial(),
      );

      await pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is SafeArea && !w.top && w.bottom,
          description: 'SafeArea du corps (bas seulement)',
        ),
        findsOneWidget,
      );
    });

    for (final (scope, name) in [
      (const MobileMoneyScope.bid(bidId), 'bid'),
      (const MobileMoneyScope.negotiation(threadId), 'negotiation'),
      (supplementScope, 'bid_supplement'),
    ]) {
      testWidgets('analytics_awaitingEvent_carriesScope_$name', (tester) async {
        stub(
          const MobileMoneyPaymentInitial(),
          previous: const MobileMoneyPaymentInitial(),
        );

        await pumpScreen(tester, scope: scope);

        verify(
          () => analyticsBackend.capture(AnalyticsEvents.mobileMoneyAwaiting, {
            'provider': 'mobile_money',
            'scope': name,
          }),
        ).called(1);
      });
    }

    testWidgets('supplement_titleIsPaySupplement', (tester) async {
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester, scope: supplementScope);

      expect(find.text('Payer le supplément'), findsOneWidget);
      expect(find.text('Payer le colis'), findsNothing);
    });

    testWidgets('parcel_titleIsPayParcel', (tester) async {
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);

      expect(find.text('Payer le colis'), findsOneWidget);
      expect(find.text('Payer le supplément'), findsNothing);
    });
  });

  group('choosePayer', () {
    testWidgets('choosePayer_showsSection_andPayDisabledUntilRecognized', (
      tester,
    ) async {
      payerOn(kPayerReady);
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);

      expect(find.text('COMPTE QUI PAIE'), findsOneWidget);
      expect(find.byKey(const Key('mm-country-field')), findsOneWidget);
      expect(tester.widget<DonyButton>(payButton()).onPressed, isNull);

      payerController.add(kPayerRecognized);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settleMotion(tester);

      expect(tester.widget<DonyButton>(payButton()).onPressed, isNotNull);
      expect(find.text('Le vôtre ou celui d\'un proche.'), findsOneWidget);
    });

    testWidgets('choosePayer_amountCard_showsAmount', (tester) async {
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);

      expect(find.text(formatPriceIn(12500, 'XOF')), findsWidgets);
    });

    testWidgets('choosePayer_firstEmission_configuresCubitWithCurrencyAndOps', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: acceptedOrangeOnly,
        ),
      );

      await pumpScreen(tester);

      verify(
        () => payerCubit.configure(
          currency: 'XOF',
          allowedOperators: {'ORANGE_CIV'},
        ),
      ).called(1);
    });

    testWidgets('choosePayer_alreadyChoosingAtOpen_configuresCubitOnce', (
      tester,
    ) async {
      // Bloc déjà à l'étape « Qui paie ? » à l'ouverture (écran remonté) : le
      // listener ne voit aucun changement de type, l'ouverture configure.
      const choosing = MobileMoneyPaymentChoosePayer(
        status: noDepositStatus,
        accepted: acceptedOrangeOnly,
      );
      stub(choosing, previous: choosing);

      await pumpScreen(tester);

      verify(
        () => payerCubit.configure(
          currency: 'XOF',
          allowedOperators: {'ORANGE_CIV'},
        ),
      ).called(1);
    });

    testWidgets('choosePayer_acceptedUnknown_noOperatorRestriction', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);

      verify(
        () => payerCubit.configure(
          currency: 'XOF',
          allowedOperators: any(named: 'allowedOperators', that: isNull),
        ),
      ).called(1);
    });

    testWidgets('choosePayer_acceptedEmpty_noOperatorRestriction', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: MobileMoneyAcceptedOperators(),
        ),
      );

      await pumpScreen(tester);

      // Une liste vide bloquerait tous les opérateurs : le back revérifie.
      verify(
        () => payerCubit.configure(
          currency: 'XOF',
          allowedOperators: any(named: 'allowedOperators', that: isNull),
        ),
      ).called(1);
    });

    testWidgets('choosePayer_disallowedOperatorGreyed', (tester) async {
      payerOn(kPayerRecognized.copyWith(allowedOperators: {'ORANGE_CIV'}));
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: acceptedOrangeOnly,
        ),
      );

      await pumpScreen(tester);

      // MTN n'est pas accepté par le voyageur : pastille grisée, libellée.
      expect(find.text('Non accepté'), findsOneWidget);
      expect(find.byKey(const Key('mm-operator-MTN_MOMO_CIV')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mm-operator-MTN_MOMO_CIV')));
      verifyNever(() => payerCubit.selectOperator(any()));
    });

    testWidgets('choosePayer_acceptsLine_namesTravelerAndOperators', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: acceptedOrangeOnly,
        ),
      );

      await pumpScreen(tester);

      expect(
        find.text(
          'Awa accepte Orange Money, et reçoit sur le réseau que vous '
          'choisissez.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('choosePayer_acceptsLine_fallsBackOnGenericTravelerName', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: MobileMoneyAcceptedOperators(
            providers: {'ORANGE_CIV', 'ORANGE_SEN', 'MTN_MOMO_CIV'},
          ),
        ),
      );

      await pumpScreen(tester);

      // « Orange Money » n'est cité qu'une fois (CI et SN), le prénom est
      // inconnu : « Le voyageur ».
      expect(
        find.text(
          'Le voyageur accepte Orange Money et MTN MoMo, et reçoit sur le '
          'réseau que vous choisissez.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('choosePayer_acceptsLine_hiddenWhenAcceptedUnknown', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);

      expect(find.textContaining('et reçoit sur le réseau'), findsNothing);
    });

    testWidgets('choosePayer_acceptsLine_hiddenUntilCatalogLoaded', (
      tester,
    ) async {
      payerOn(const PayerAccountState());
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: acceptedOrangeOnly,
        ),
      );

      await pumpScreen(tester);

      expect(find.textContaining('et reçoit sur le réseau'), findsNothing);
    });

    testWidgets(
      'choosePayer_pay_requiresAuth_thenInitiatesWithE164AndProvider',
      (tester) async {
        stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

        await pumpScreen(tester);
        await tester.tap(payButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        verify(
          () => bloc.add(
            const MobileMoneyPaymentInitiateRequested(
              scope: scope,
              phoneNumber: '+2250748840856',
              provider: 'ORANGE_CIV',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('choosePayer_authRefused_noInitiate', (tester) async {
      when(() => authService.isPinSet()).thenAnswer((_) async => true);
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);
      await tester.tap(payButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Refuser le PIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      verifyNever(
        () => bloc.add(any(that: isA<MobileMoneyPaymentInitiateRequested>())),
      );
      expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
    });

    testWidgets('choosePayer_payerNoLongerRecognizedAfterAuth_noInitiate', (
      tester,
    ) async {
      // Le numéro change pendant la vérification biométrique : jamais un
      // dépôt sur un numéro qui n'est plus reconnu.
      when(
        () => userPrefsBox.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);
      final gate = Completer<bool>();
      when(
        () => authService.isBiometricAvailable(),
      ).thenAnswer((_) async => true);
      when(
        () => authService.authenticateWithBiometric(),
      ).thenAnswer((_) => gate.future);
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);
      await tester.tap(payButton());
      await tester.pump();
      payerController.add(kPayerReady);
      await tester.pump();
      gate.complete(true);
      await tester.pump();
      await tester.pump();

      verifyNever(
        () => bloc.add(any(that: isA<MobileMoneyPaymentInitiateRequested>())),
      );
    });

    testWidgets('choosePayer_submitting_buttonLoadingAndInactive', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          isSubmitting: true,
        ),
      );

      await pumpScreen(tester);

      final button = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(button.onPressed, isNull);
      expect(button.isLoading, isTrue);
    });

    testWidgets('choosePayer_error_showsBanner', (tester) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          error: ValidationException(
            'Opérateur refusé',
            code: 'mobile-money-operator-not-accepted',
          ),
        ),
      );

      await pumpScreen(tester);

      expect(find.byType(DonyStatusBanner), findsOneWidget);
      expect(payButton(), findsOneWidget);
    });

    testWidgets('choosePayer_phoneRequiredError_explainsInBanner', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          error: ValidationException(
            'Aucun numéro',
            code: 'mobile-money-phone-required',
          ),
        ),
      );

      await pumpScreen(tester);

      expect(
        find.text(
          'Votre compte Yadony n\'a pas de numéro de téléphone : indiquez le '
          'numéro mobile money qui paiera.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('choosePayer_payerUnsupportedError_explainsInBanner', (
      tester,
    ) async {
      stub(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          error: ValidationException(
            'Numéro refusé',
            code: 'mobile-money-payer-unsupported',
          ),
        ),
      );

      await pumpScreen(tester);

      expect(
        find.textContaining('Ce numéro ne peut pas payer en mobile money'),
        findsOneWidget,
      );
    });

    testWidgets('choosePayer_pollingIsStopped', (tester) async {
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));

      verifyNever(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>())));
    });

    testWidgets('choosePayer_countdown_shownWhenDeadlineKnown', (tester) async {
      stub(
        MobileMoneyPaymentChoosePayer(
          status: MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            amount: 12500,
            deadlineAt: DateTime.now().toUtc().add(const Duration(minutes: 20)),
          ),
        ),
      );

      await pumpScreen(tester);

      expect(countdownFinder, findsOneWidget);
    });

    testWidgets('choosePayer_countdown_hiddenWithoutDeadline', (tester) async {
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);

      expect(find.textContaining('Temps restant'), findsNothing);
    });

    testWidgets('choosePayer_countdown_hoursMinutesSecondsBeyondOneHour', (
      tester,
    ) async {
      stub(
        MobileMoneyPaymentChoosePayer(
          status: MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'PENDING',
            deadlineAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
            amount: 1500,
          ),
        ),
      );

      await pumpScreen(tester, scope: supplementScope);
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              RegExp(r'^Temps restant [12]:[0-5]\d:[0-5]\d$').hasMatch(w.data!),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('120:'), findsNothing);
    });

    testWidgets('choosePayer_countdown_urgentUnderFiveMinutesIsRed', (
      tester,
    ) async {
      stub(
        MobileMoneyPaymentChoosePayer(
          status: MobileMoneyPaymentStatus(
            subjectId: bidId,
            amount: 12500,
            deadlineAt: DateTime.now().toUtc().add(const Duration(minutes: 3)),
          ),
        ),
      );

      await pumpScreen(tester);

      final text = tester.widget<Text>(countdownFinder);
      expect(text.style?.color, AppTheme.light().colorScheme.error);
    });

    testWidgets('choosePayer_secondEmission_restrictsOperatorsWithoutReload', (
      tester,
    ) async {
      final controller = StreamController<MobileMoneyPaymentState>.broadcast();
      addTearDown(controller.close);
      final emit = drive(const MobileMoneyPaymentLoading(), controller);

      await pumpScreen(tester);
      // Premier « Qui paie ? » : le catalogue est chargé une seule fois.
      emit(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));
      await tester.pump();

      emit(MobileMoneyPaymentAwaitingConfirmation(awaitingStatus()));
      await tester.pump();
      emit(MobileMoneyPaymentDepositFailed(failedStatus()));
      await tester.pump();
      emit(
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: acceptedOrangeOnly,
        ),
      );
      await tester.pump();

      // « Payer avec un autre numéro » : le compte saisi reste affiché, le
      // cubit n'est jamais rechargé, seule la restriction est remise à jour.
      verify(
        () => payerCubit.configure(
          currency: any(named: 'currency'),
          allowedOperators: any(named: 'allowedOperators'),
        ),
      ).called(1);
      verify(() => payerCubit.restrictOperators({'ORANGE_CIV'})).called(1);
      await settleMotion(tester);
    });

    testWidgets('choosePayer_legacy_showsPlainPhoneField', (tester) async {
      payerOn(const PayerAccountState(status: PayerAccountStatus.legacy));
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);

      expect(
        find.byKey(const Key('mobile-money-legacy-phone-field')),
        findsOneWidget,
      );
      expect(find.text('COMPTE QUI PAIE'), findsNothing);
      expect(tester.widget<DonyButton>(payButton()).onPressed, isNotNull);

      await tester.enterText(
        find.byKey(const Key('mobile-money-legacy-phone-field')),
        '07 48 84 08 56',
      );
      await tester.tap(payButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Sans catalogue (back ancien) : numéro normalisé, opérateur laissé au
      // back.
      verify(
        () => bloc.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '0748840856',
          ),
        ),
      ).called(1);
    });

    testWidgets('choosePayer_legacy_emptyField_sendsNoNumber', (tester) async {
      payerOn(const PayerAccountState(status: PayerAccountStatus.legacy));
      stub(const MobileMoneyPaymentChoosePayer(status: noDepositStatus));

      await pumpScreen(tester);
      await tester.tap(payButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () => bloc.add(const MobileMoneyPaymentInitiateRequested(scope: scope)),
      ).called(1);
    });

    testWidgets('choosePayer_darkTheme_noOverflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      stub(
        MobileMoneyPaymentChoosePayer(
          status: MobileMoneyPaymentStatus(
            subjectId: bidId,
            amount: 12500,
            deadlineAt: DateTime.now().toUtc().add(const Duration(minutes: 3)),
          ),
          accepted: acceptedOrangeOnly,
          error: const ValidationException(
            'Opérateur refusé',
            code: 'mobile-money-operator-not-accepted',
          ),
        ),
      );

      await pumpScreen(tester, theme: AppTheme.dark());

      expect(tester.takeException(), isNull);
      expect(payButton(), findsOneWidget);
    });
  });

  group('awaiting', () {
    testWidgets('awaiting_smsLinkHint_showsSmsTexts_noBottomButtons', (
      tester,
    ) async {
      stub(MobileMoneyPaymentAwaitingConfirmation(awaitingStatus()));

      await pumpScreen(tester);

      expect(find.text('SMS envoyé au +225 07 •• •• 56'), findsOneWidget);
      expect(
        find.text('Ouvrez-le et cliquez sur le lien pour valider le paiement.'),
        findsOneWidget,
      );
      // Récapitulatif : montant, compte qui paie, versement au voyageur.
      expect(find.text('Montant'), findsOneWidget);
      expect(find.text(formatPriceIn(12500, 'XOF')), findsOneWidget);
      expect(find.text('Depuis'), findsOneWidget);
      expect(find.text('Orange Money ••56'), findsOneWidget);
      expect(find.text('Versé au voyageur'), findsOneWidget);
      expect(find.text('À la livraison'), findsOneWidget);
      // Seul le ✕ fait sortir : aucun bouton en bas.
      expect(find.byType(DonyButton), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('awaiting_pinPromptHint_showsPromptTexts', (tester) async {
      stub(
        MobileMoneyPaymentAwaitingConfirmation(
          awaitingStatus(hint: MobileMoneyValidationHint.pinPrompt),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('Demande envoyée au +225 07 •• •• 56'), findsOneWidget);
      expect(
        find.text(
          'Une fenêtre s\'affiche sur votre téléphone : validez avec votre '
          'code secret.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('awaiting_unknownProvider_hidesFromRow', (tester) async {
      stub(
        MobileMoneyPaymentAwaitingConfirmation(
          awaitingStatus(providerLabel: null),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('Depuis'), findsNothing);
      expect(find.text('Montant'), findsOneWidget);
    });

    testWidgets('awaiting_unknownNumber_fromRowKeepsOperatorOnly', (
      tester,
    ) async {
      stub(
        MobileMoneyPaymentAwaitingConfirmation(
          awaitingStatus(msisdnMasked: null),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('Depuis'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
    });

    testWidgets('awaiting_waveLink_opensAuthorizationUrl', (tester) async {
      stub(
        MobileMoneyPaymentAwaitingConfirmation(
          awaitingStatus(
            providerLabel: 'Wave',
            authorizationUrl: 'https://pay.wave.com/abc123',
          ),
        ),
      );

      await pumpScreen(tester);
      await tester.tap(find.text('Ouvrir Wave'));
      await tester.pump();

      verify(
        () => urlLauncher.open(Uri.parse('https://pay.wave.com/abc123')),
      ).called(1);
    });

    testWidgets('awaiting_waveLinkWithoutLabel_stillOffersWaveButton', (
      tester,
    ) async {
      // Back ancien : lien sans nom d'opérateur. Le lien d'autorisation n'est
      // propre qu'à Wave : le bouton reste proposé, jamais une assertion.
      stub(
        MobileMoneyPaymentAwaitingConfirmation(
          awaitingStatus(
            providerLabel: null,
            authorizationUrl: 'https://pay.wave.com/abc123',
          ),
        ),
      );

      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Ouvrir Wave'), findsOneWidget);
    });

    testWidgets('awaiting_noDeadline_stillShowsPanel', (tester) async {
      stub(
        const MobileMoneyPaymentAwaitingConfirmation(
          MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'PENDING',
            amount: 12500,
            deposit: MobileMoneyDeposit(
              id: 'd',
              status: MobileMoneyDepositStatus.accepted,
              providerLabel: 'Orange Money',
              msisdnMasked: '+225 07 •• •• 56',
            ),
          ),
        ),
      );

      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Demande envoyée au +225 07 •• •• 56'), findsOneWidget);
    });

    testWidgets('awaiting_closeButton_popsFalse', (tester) async {
      stub(MobileMoneyPaymentAwaitingConfirmation(awaitingStatus()));

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('host'), findsOneWidget);
      expect(await poppedResult, isFalse);
    });

    testWidgets('awaiting_polling_sendsPolledEveryFiveSeconds', (tester) async {
      stub(MobileMoneyPaymentAwaitingConfirmation(awaitingStatus()));

      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 5));

      verify(
        () => bloc.add(any(that: isA<MobileMoneyStatusPolled>())),
      ).called(1);
    });

    testWidgets('awaiting_recapAndTitle_translatedInEnglish', (tester) async {
      useEnglish();
      stub(MobileMoneyPaymentAwaitingConfirmation(awaitingStatus()));

      await pumpScreen(tester);

      expect(find.text('Pay for the parcel'), findsOneWidget);
      expect(find.text('Paid to the traveler'), findsOneWidget);
      expect(find.text('On delivery'), findsOneWidget);
      expect(find.text('From'), findsOneWidget);
    });
  });

  group('overdue', () {
    testWidgets('overdue_showsNotYetApproved_neverExpiredText', (tester) async {
      stub(MobileMoneyPaymentOverdue(awaitingStatus()));

      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Pas encore validé'), findsOneWidget);
      expect(
        find.text(
          'Si vous validez quand même dans les prochaines minutes, votre '
          'paiement sera pris en compte.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Délai dépassé'), findsNothing);
      expect(find.byType(DonyButton), findsNothing);
      // Le sondage continue jusqu'à l'issue.
      verify(
        () => bloc.add(any(that: isA<MobileMoneyStatusPolled>())),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  group('failed', () {
    testWidgets('failed_showsTranslatedReason_andBothButtons', (tester) async {
      stub(
        MobileMoneyPaymentDepositFailed(
          failedStatus(code: 'insufficient-balance', message: 'Solde bas'),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('Paiement non abouti'), findsOneWidget);
      expect(
        find.text('Solde insuffisant sur votre compte mobile money.'),
        findsOneWidget,
      );
      expect(find.text('Solde bas'), findsNothing);
      expect(
        find.byKey(const Key('mobile-money-awaiting-resend')),
        findsOneWidget,
      );
      expect(find.text('Renvoyer une demande'), findsOneWidget);
      expect(find.text('Payer avec un autre numéro'), findsOneWidget);
    });

    testWidgets('failed_unknownCode_usesBackendMessage', (tester) async {
      stub(
        MobileMoneyPaymentDepositFailed(
          failedStatus(code: 'nouveau-code', message: 'Motif du back'),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('Motif du back'), findsOneWidget);
    });

    testWidgets('failed_noCodeNoMessage_usesGenericReason', (tester) async {
      stub(
        MobileMoneyPaymentDepositFailed(
          failedStatus(status: MobileMoneyDepositStatus.submitRejected),
        ),
      );

      await pumpScreen(tester);

      expect(
        find.text('Le paiement a été refusé par l\'opérateur.'),
        findsOneWidget,
      );
    });

    testWidgets('failed_noKnownPayer_hidesResend', (tester) async {
      when(() => bloc.canResend).thenReturn(false);
      stub(MobileMoneyPaymentDepositFailed(failedStatus(code: 'other')));

      await pumpScreen(tester);

      expect(
        find.byKey(const Key('mobile-money-awaiting-resend')),
        findsNothing,
      );
      expect(find.text('Renvoyer une demande'), findsNothing);
      expect(find.text('Payer avec un autre numéro'), findsOneWidget);
    });

    testWidgets('failed_resend_requiresAuth_thenResends', (tester) async {
      stub(MobileMoneyPaymentDepositFailed(failedStatus(code: 'not-approved')));

      await pumpScreen(tester);
      await tester.tap(find.text('Renvoyer une demande'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () => bloc.add(const MobileMoneyPaymentResendRequested(scope: scope)),
      ).called(1);
    });

    testWidgets('failed_resendRefused_snackbarAndNoResend', (tester) async {
      when(() => authService.isPinSet()).thenAnswer((_) async => true);
      stub(MobileMoneyPaymentDepositFailed(failedStatus(code: 'not-approved')));

      await pumpScreen(tester);
      await tester.tap(find.text('Renvoyer une demande'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Refuser le PIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      verifyNever(
        () => bloc.add(any(that: isA<MobileMoneyPaymentResendRequested>())),
      );
      expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
    });

    testWidgets('failed_payWithAnotherNumber_backToChoosePayer', (
      tester,
    ) async {
      stub(MobileMoneyPaymentDepositFailed(failedStatus(code: 'not-approved')));

      await pumpScreen(tester);
      await tester.tap(find.text('Payer avec un autre numéro'));
      await tester.pump();

      verify(
        () => bloc.add(
          const MobileMoneyPaymentChangePayerRequested(scope: scope),
        ),
      ).called(1);
    });

    testWidgets('failed_pollingIsStopped', (tester) async {
      stub(MobileMoneyPaymentDepositFailed(failedStatus(code: 'other')));

      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 6));

      verifyNever(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>())));
    });
  });

  group('expired', () {
    testWidgets('expired_bid_textAndBackPopsFalse', (tester) async {
      stub(const MobileMoneyPaymentExpired(expiredStatus));

      await pumpScreen(tester);

      expect(
        find.text(
          'Délai dépassé. La demande a été annulée, refaites une offre au '
          'voyageur.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Retour'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('host'), findsOneWidget);
      expect(await poppedResult, isFalse);
    });

    testWidgets('expired_negotiation_threadBackToPayable', (tester) async {
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
          'Délai dépassé. Le fil est revenu à « à payer » : vous pouvez '
          'relancer le paiement ou changer de moyen de paiement depuis le '
          'fil.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('La demande a été annulée'), findsNothing);
    });

    testWidgets('expired_supplement_requestClosed', (tester) async {
      stub(
        const MobileMoneyPaymentExpired(
          MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'CANCELLED',
            amount: 1500,
          ),
        ),
      );

      await pumpScreen(tester, scope: supplementScope);

      expect(
        find.text(
          'Ce supplément n\'est plus à payer : la demande a expiré ou a été '
          'close. Le colis reste au prix prévu.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('refaites une offre'), findsNothing);
    });

    for (final (status, text) in [
      ('REFUND_PENDING', 'Remboursement du supplément en cours'),
      ('REFUNDED', 'Le supplément vous a été remboursé'),
    ]) {
      testWidgets('expired_supplement_refund_$status', (tester) async {
        stub(
          MobileMoneyPaymentExpired(
            MobileMoneyPaymentStatus(
              subjectId: bidId,
              paymentStatus: status,
              amount: 1500,
            ),
          ),
        );

        await pumpScreen(tester, scope: supplementScope);

        expect(find.text(text), findsOneWidget);
        expect(find.textContaining('plus à payer'), findsNothing);
      });
    }

    testWidgets('expired_bid_translatedInEnglish', (tester) async {
      useEnglish();
      stub(const MobileMoneyPaymentExpired(expiredStatus));

      await pumpScreen(tester);

      expect(
        find.text(
          "Time's up. The request was canceled. Make a new offer to the "
          'traveler.',
        ),
        findsOneWidget,
      );
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('expired_deepLink_backGoesToParcelDetail', (tester) async {
      stub(const MobileMoneyPaymentExpired(expiredStatus));

      await pumpDeepLinked(tester);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('detail $bidId'), findsOneWidget);
    });
  });

  group('escrowed', () {
    testWidgets('escrowed_remembersPayer_andCloses', (tester) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpScreen(tester);

      verify(() => payerCubit.rememberSuccess()).called(1);
      expect(find.text('host'), findsOneWidget);
      expect(
        find.text('Paiement confirmé, votre envoi est sécurisé'),
        findsOneWidget,
      );
      expect(await poppedResult, isTrue);
    });

    testWidgets('escrowed_timersAreCancelled_noMorePolling', (tester) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 6));

      // verify(...).called(0) échoue toujours chez mocktail : verifyNever.
      verifyNever(() => bloc.add(any(that: isA<MobileMoneyStatusPolled>())));
    });

    testWidgets('escrowed_supplement_paidSnackbar', (tester) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpScreen(tester, scope: supplementScope);

      expect(find.text('Supplément payé'), findsOneWidget);
      expect(
        find.text('Paiement confirmé, votre envoi est sécurisé'),
        findsNothing,
      );
      expect(await poppedResult, isTrue);
    });

    testWidgets('escrowed_deepLink_parcelDetail_noNothingToPop', (
      tester,
    ) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpDeepLinked(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('detail $bidId'), findsOneWidget);
    });

    testWidgets('escrowed_deepLink_negotiation_threadScreen', (tester) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpDeepLinked(
        tester,
        scope: const MobileMoneyScope.negotiation(threadId),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('thread $threadId'), findsOneWidget);
    });

    testWidgets('escrowed_deepLink_supplement_parcelDetail', (tester) async {
      stub(const MobileMoneyPaymentEscrowed(escrowedStatus));

      await pumpDeepLinked(tester, scope: supplementScope);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('detail $bidId'), findsOneWidget);
    });
  });

  group('error', () {
    testWidgets('error_genericMessage_retryReopens', (tester) async {
      stub(const MobileMoneyPaymentError(NetworkException('boom interne')));

      await pumpScreen(tester);

      // Jamais le détail technique brut affiché à l'utilisateur.
      expect(find.text('boom interne'), findsNothing);
      expect(find.text('Une erreur est survenue'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(
        () => bloc.add(any(that: isA<MobileMoneyPaymentOpened>())),
      ).called(2);
    });
  });
}

const _fifteenMinutes = Duration(minutes: 15);
