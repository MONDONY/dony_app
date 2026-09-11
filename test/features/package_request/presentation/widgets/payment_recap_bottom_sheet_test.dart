import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/negotiation_paid_success_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/error_reporting_test_doubles.dart';

/// Widget test for `PaymentRecapBottomSheet.show()` — the static sheet
/// launcher itself, NOT `PaymentRecapContent` (already covered in depth by
/// `payment_recap_test.dart`, which pumps the content widget directly).
///
/// This file exercises the real Stripe branch (`onSuccess` of
/// `DonyPaymentSheet.show`) end to end: biometric auth → `initiatePayment` →
/// PayPal confirmation → `NegotiationCheckoutRequested` dispatch →
/// `DonySuccessScreen` → CTA navigation.

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBox extends Mock implements Box {}

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockNegotiationRepository extends Mock
    implements NegotiationRepository {}

/// [HiveService.userPrefs] normally opens a real Hive box — overridden here
/// so tests can inject a [Box] mock without touching the filesystem.
class _FakeHiveService extends HiveService {
  _FakeHiveService(this._box);
  final Box _box;

  @override
  Box get userPrefs => _box;
}

NegotiationThread _makeThread({
  double currentPriceEur = 35.0,
  double? grossPriceEur = 39.20,
  PaymentMethod? paymentMethod = PaymentMethod.stripe,
}) {
  return NegotiationThread(
    id: 'thread-recap-1',
    packageRequestId: 'pr-1',
    travelerId: 'traveler-1',
    travelerTravelDate: DateTime(2026, 7, 15),
    travelerAvailableKg: 10,
    status: NegotiationThreadStatus.awaitingPayment,
    currentPriceEur: currentPriceEur,
    grossPriceEur: grossPriceEur,
    paymentMethod: paymentMethod,
    roundsCount: 3,
    lastActivityAt: DateTime(2026, 6, 1, 10),
    createdAt: DateTime(2026, 5, 28, 9),
    messages: [
      NegotiationMessage(
        id: 'm1',
        threadId: 'thread-recap-1',
        fromUserId: 'traveler-1',
        kind: NegotiationMessageKind.proposal,
        proposedPriceEur: 35.0,
        createdAt: DateTime(2026, 6, 1, 10),
      ),
    ],
  );
}

void main() {
  late _MockNegotiationBloc bloc;

  setUp(() {
    // DonyPaymentSheet.show resout ErrorReportingService via GetIt.
    registerNoopErrorReporting();

    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  tearDown(() => bloc.close());

  // ── Checkout Stripe réussi → DonySuccessScreen ─────────────────────────

  group('Paiement Stripe réussi', () {
    late _MockLocalAuthService authService;
    late _MockBox userPrefsBox;
    late _MockPaymentGateway paymentGateway;
    late _MockPaymentRepository paymentRepository;
    late _MockNegotiationRepository negotiationRepository;

    setUpAll(() {
      registerFallbackValue(
        const NegotiationCheckoutRequested(
          threadId: 'thread-recap-1',
          paymentIntentId: 'pi_test',
        ),
      );
    });

    setUp(() {
      authService = _MockLocalAuthService();
      userPrefsBox = _MockBox();
      // Biométrie activée + réussie → requirePaymentAuth ne passe jamais par
      // l'écran PIN '/auth/local' (pas de route stub nécessaire).
      when(
        () => userPrefsBox.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);
      when(
        () => authService.isBiometricAvailable(),
      ).thenAnswer((_) async => true);
      when(
        () => authService.authenticateWithBiometric(),
      ).thenAnswer((_) async => true);

      paymentGateway = _MockPaymentGateway();
      // PlatformPayButton (Apple/Google Pay) plante hors iOS/Android réel —
      // on désactive le wallet et paie via PayPal (bouton Flutter classique).
      when(
        () => paymentGateway.isPlatformPaySupported(),
      ).thenAnswer((_) async => false);
      when(() => paymentGateway.confirmPayPal(any())).thenAnswer((_) async {});

      paymentRepository = _MockPaymentRepository();
      negotiationRepository = _MockNegotiationRepository();
      when(
        () => negotiationRepository.initiatePayment('thread-recap-1'),
      ).thenAnswer(
        (_) async => (
          clientSecret: 'pi_test_secret',
          paymentIntentId: 'pi_test',
          amountEur: 39.20,
          currencyCode: 'EUR',
          paymentMethodTypes: ['paypal'],
        ),
      );

      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      getIt.registerFactory<LocalAuthService>(() => authService);

      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
      getIt.registerFactory<HiveService>(() => _FakeHiveService(userPrefsBox));

      if (getIt.isRegistered<PaymentGateway>()) {
        getIt.unregister<PaymentGateway>();
      }
      getIt.registerFactory<PaymentGateway>(() => paymentGateway);

      if (getIt.isRegistered<PaymentRepository>()) {
        getIt.unregister<PaymentRepository>();
      }
      getIt.registerFactory<PaymentRepository>(() => paymentRepository);

      if (getIt.isRegistered<NegotiationRepository>()) {
        getIt.unregister<NegotiationRepository>();
      }
      getIt.registerFactory<NegotiationRepository>(() => negotiationRepository);
    });

    tearDown(() {
      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
      if (getIt.isRegistered<PaymentGateway>()) {
        getIt.unregister<PaymentGateway>();
      }
      if (getIt.isRegistered<PaymentRepository>()) {
        getIt.unregister<PaymentRepository>();
      }
      if (getIt.isRegistered<NegotiationRepository>()) {
        getIt.unregister<NegotiationRepository>();
      }
    });

    Widget buildRoutedApp() {
      final thread = _makeThread();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, state) => Scaffold(
              body: BlocProvider.value(
                value: bloc,
                child: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open'),
                    onPressed: () => PaymentRecapBottomSheet.show(
                      ctx,
                      bloc: bloc,
                      thread: thread,
                    ),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/negotiations/:id',
            builder: (_, state) => Scaffold(
              body: Center(
                child: Text('Fil de négociation ${state.pathParameters['id']}'),
              ),
            ),
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
    }

    testWidgets('onSuccess du paiement Stripe → NegotiationCheckoutRequested + '
        'DonySuccessScreen puis CTA vers /negotiations/{threadId}', (
      tester,
    ) async {
      await tester.pumpWidget(buildRoutedApp());
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // Confirme le paiement (auth biométrique mockée en succès) → ouvre la
      // DonyPaymentSheet Stripe. `pumpAndSettle` n'est PAS utilisable ici : le
      // bouton "Payer" de la sheet extérieure passe en `isLoading: true`
      // (spinner indéterminé) et reste monté sous la DonyPaymentSheet tant
      // que celle-ci n'est pas fermée — `pumpAndSettle` ne convergerait
      // jamais. On enchaîne donc des pumps bornés pour vider les gaps async
      // (requirePaymentAuth, initiatePayment, ouverture de la sheet,
      // PaymentSheetStarted).
      await tester.tap(find.text('Payer 39,20 €'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // La DonyPaymentSheet est ouverte (PayPal dispo, aucune carte
      // enregistrée) → on paie via le bouton PayPal.
      expect(find.byKey(const Key('paymentSheetPayPalButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('paymentSheetPayPalButton')));
      await tester.pump(); // PaymentSheetProcessing
      await tester.pump(); // PaymentSheetSuccess (résolution async du gateway)
      await tester.pump(
        const Duration(milliseconds: 900),
      ); // déclenchement onSuccess
      // Laisse l'animation de fermeture de la sheet extérieure se terminer —
      // toujours pas de pumpAndSettle, même raison que ci-dessus.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      verify(
        () => bloc.add(
          any(
            that: isA<NegotiationCheckoutRequested>()
                .having((e) => e.threadId, 'threadId', 'thread-recap-1')
                .having((e) => e.paymentIntentId, 'paymentIntentId', 'pi_test'),
          ),
        ),
      ).called(1);

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Offre acceptée et payée !'), findsOneWidget);

      await tester.ensureVisible(find.text('Voir le suivi'));
      await tester.tap(find.text('Voir le suivi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Fil de négociation thread-recap-1'), findsOneWidget);
    });
  });

  // ── Confirmation cash → DonySuccessScreen ──────────────────────────────

  group('Confirmation accord cash', () {
    setUpAll(() {
      registerFallbackValue(
        const NegotiationCheckoutRequested(
          threadId: 'thread-recap-1',
          paymentIntentId: kCashPaymentSentinel,
        ),
      );
    });

    Widget buildRoutedApp() {
      final thread = _makeThread(paymentMethod: PaymentMethod.cash);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, state) => Scaffold(
              body: BlocProvider.value(
                value: bloc,
                child: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open'),
                    onPressed: () => PaymentRecapBottomSheet.show(
                      ctx,
                      bloc: bloc,
                      thread: thread,
                    ),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/negotiations/:id',
            builder: (_, state) => Scaffold(
              body: Center(
                child: Text('Fil de négociation ${state.pathParameters['id']}'),
              ),
            ),
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
    }

    testWidgets(
      'confirmation cash → NegotiationCheckoutRequested(kCashPaymentSentinel) '
      '+ DonySuccessScreen "Accord confirmé !" puis CTA vers /negotiations/{threadId}',
      (tester) async {
        await tester.pumpWidget(buildRoutedApp());
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(DonyButton, 'Confirmer l\'accord'),
        );
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            any(
              that: isA<NegotiationCheckoutRequested>()
                  .having((e) => e.threadId, 'threadId', 'thread-recap-1')
                  .having(
                    (e) => e.paymentIntentId,
                    'paymentIntentId',
                    kCashPaymentSentinel,
                  ),
            ),
          ),
        ).called(1);

        expect(find.byType(DonySuccessScreen), findsOneWidget);
        expect(find.text('Accord confirmé !'), findsOneWidget);

        await tester.ensureVisible(find.text('Voir le suivi'));
        await tester.tap(find.text('Voir le suivi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Fil de négociation thread-recap-1'), findsOneWidget);
      },
    );
  });

  // ── Paiement mobile money → écran d'attente → écran de succès ──────────

  group('Paiement mobile money', () {
    late _MockLocalAuthService authService;
    late _MockBox userPrefsBox;
    late _MockAuthBloc authBloc;

    setUpAll(() {
      registerFallbackValue(const NegotiationFetchRequested('thread-recap-1'));
    });

    setUp(() {
      authService = _MockLocalAuthService();
      userPrefsBox = _MockBox();
      // Biométrie activée + réussie : requirePaymentAuth répond vrai sans
      // passer par l'écran PIN.
      when(
        () => userPrefsBox.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);
      when(
        () => authService.isBiometricAvailable(),
      ).thenAnswer((_) async => true);
      when(
        () => authService.authenticateWithBiometric(),
      ).thenAnswer((_) async => true);

      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      getIt.registerFactory<LocalAuthService>(() => authService);
      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
      getIt.registerFactory<HiveService>(() => _FakeHiveService(userPrefsBox));

      // Compte connecté avec un numéro : le champ payeur doit démarrer dessus.
      authBloc = _MockAuthBloc();
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(
          UserModel(
            id: 'u1',
            roles: [],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
            phoneNumber: '+221771234567',
          ),
        ),
      );
    });

    tearDown(() {
      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
      authBloc.close();
    });

    /// Routeur de test : la vraie route d'attente est remplacée par un stub qui
    /// capture `state.extra` (le numéro payeur normalisé) et se referme avec
    /// le résultat choisi ; la route de succès monte le vrai
    /// [NegotiationPaidSuccessScreen].
    Widget buildRoutedApp({required List<Object?> capturedExtras}) {
      final thread = _makeThread(paymentMethod: PaymentMethod.mobileMoney);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, state) => Scaffold(
              body: BlocProvider.value(
                value: bloc,
                child: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open'),
                    onPressed: () => PaymentRecapBottomSheet.show(
                      ctx,
                      bloc: bloc,
                      thread: thread,
                    ),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/negotiations/:id/mobile-money/awaiting',
            builder: (ctx, state) {
              capturedExtras.add(state.extra);
              return Scaffold(
                body: Column(
                  children: [
                    Text('ATTENTE ${state.pathParameters['id']}'),
                    ElevatedButton(
                      key: const Key('deposit-ok'),
                      onPressed: () => ctx.pop(true),
                      child: const Text('séquestré'),
                    ),
                    ElevatedButton(
                      key: const Key('deposit-expired'),
                      onPressed: () => ctx.pop(false),
                      child: const Text('expiré'),
                    ),
                  ],
                ),
              );
            },
          ),
          GoRoute(
            path: '/negotiations/:id/paid',
            builder: (_, state) => NegotiationPaidSuccessScreen(
              threadId: state.pathParameters['id']!,
            ),
          ),
          // Repli PIN de requirePaymentAuth quand la biométrie échoue : le
          // stub refuse (pop false).
          GoRoute(
            path: '/auth/local',
            builder: (ctx, _) => Scaffold(
              body: ElevatedButton(
                key: const Key('pin-refuse'),
                onPressed: () => ctx.pop(false),
                child: const Text('refuser'),
              ),
            ),
          ),
          GoRoute(
            path: '/negotiations/:id',
            builder: (_, state) => Scaffold(
              body: Center(
                child: Text('Fil de négociation ${state.pathParameters['id']}'),
              ),
            ),
          ),
        ],
      );
      return BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      );
    }

    testWidgets(
      'la feuille affiche le titre, la bannière, le champ pré-rempli avec le '
      'numéro du compte et le bouton « Payer … par mobile money »',
      (tester) async {
        await tester.pumpWidget(buildRoutedApp(capturedExtras: []));
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();

        expect(find.text('Payer par mobile money'), findsOneWidget);
        expect(
          find.textContaining('Tu valides le paiement sur ton téléphone'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('payer-phone-field')), findsOneWidget);
        expect(find.text('+221771234567'), findsOneWidget);
        expect(
          find.widgetWithText(
            DonyButton,
            'Payer 39,20\u00A0€ par mobile money',
          ),
          findsOneWidget,
        );
        // Aucune ligne « espèces », la grille est celle d'un paiement en ligne.
        expect(find.text('Total à payer'), findsOneWidget);
        expect(find.text('À remettre au voyageur (en espèces)'), findsNothing);
      },
    );

    testWidgets(
      'tap → route d\'attente poussée avec le numéro saisi normalisé en extra ; '
      'dépôt séquestré → rechargement du fil + écran « Offre acceptée et payée ! » '
      'puis CTA vers /negotiations/{threadId}',
      (tester) async {
        final extras = <Object?>[];
        await tester.pumpWidget(buildRoutedApp(capturedExtras: extras));
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('payer-phone-field')),
          '+221 77 345 67 89',
        );
        // Referme la sélection : sa poignée, dessinée dans l'overlay juste
        // sous le champ, recouvre sinon le bouton du stickyBottom.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(
            DonyButton,
            'Payer 39,20\u00A0€ par mobile money',
          ),
        );
        await tester.pumpAndSettle();

        expect(extras, ['+221773456789']);
        expect(find.text('ATTENTE thread-recap-1'), findsOneWidget);
        // Rien n'est envoyé au bloc tant que l'écran d'attente est ouvert.
        verifyNever(() => bloc.add(any()));

        await tester.tap(find.byKey(const Key('deposit-ok')));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            any(
              that: isA<NegotiationFetchRequested>().having(
                (e) => e.threadId,
                'threadId',
                'thread-recap-1',
              ),
            ),
          ),
        ).called(1);
        expect(find.byType(NegotiationPaidSuccessScreen), findsOneWidget);
        expect(find.text('Offre acceptée et payée !'), findsOneWidget);

        await tester.ensureVisible(find.text('Voir le suivi'));
        await tester.tap(find.text('Voir le suivi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Fil de négociation thread-recap-1'), findsOneWidget);
      },
    );

    testWidgets(
      'champ vidé → extra null (repli backend sur le numéro Firebase) ; '
      'dépôt expiré → le fil est rechargé mais aucun écran de succès',
      (tester) async {
        final extras = <Object?>[];
        await tester.pumpWidget(buildRoutedApp(capturedExtras: extras));
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('payer-phone-field')), '');
        await tester.pump();
        await tester.tap(
          find.widgetWithText(
            DonyButton,
            'Payer 39,20\u00A0€ par mobile money',
          ),
        );
        await tester.pumpAndSettle();

        expect(extras, [null]);

        await tester.tap(find.byKey(const Key('deposit-expired')));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(any(that: isA<NegotiationFetchRequested>())),
        ).called(1);
        expect(find.byType(NegotiationPaidSuccessScreen), findsNothing);
        expect(find.byKey(const Key('open')), findsOneWidget);
      },
    );

    testWidgets(
      'authentification refusée (biométrie puis PIN) → la feuille reste '
      'ouverte, avertissement, aucune route d\'attente poussée',
      (tester) async {
        when(
          () => authService.authenticateWithBiometric(),
        ).thenAnswer((_) async => false);
        when(() => authService.isPinSet()).thenAnswer((_) async => true);
        final extras = <Object?>[];
        await tester.pumpWidget(buildRoutedApp(capturedExtras: extras));
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(
            DonyButton,
            'Payer 39,20\u00A0€ par mobile money',
          ),
        );
        await tester.pumpAndSettle();

        // Biométrie refusée → repli sur l'écran PIN, que l'on refuse aussi.
        await tester.tap(find.byKey(const Key('pin-refuse')));
        await tester.pumpAndSettle();

        expect(extras, isEmpty);
        expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
        expect(find.text('Payer par mobile money'), findsOneWidget);
        verifyNever(() => bloc.add(any()));

        // Laisse le snackbar se retirer (timer) avant la fin du test.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
    );
  });
}
