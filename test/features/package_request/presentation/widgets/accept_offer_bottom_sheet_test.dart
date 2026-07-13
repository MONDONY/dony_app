import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

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

Widget _buildApp({
  required _MockNegotiationBloc bloc,
  bool isTraveler = false,
  bool isCheckout = false,
  double? grossPriceEur,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: BlocProvider.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('open'),
            onPressed: () => AcceptOfferBottomSheet.show(
              ctx,
              bloc: bloc,
              threadId: 't-1',
              priceEur: 35.0,
              grossPriceEur: grossPriceEur,
              isTraveler: isTraveler,
              isCheckout: isCheckout,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _MockNegotiationBloc bloc;

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  tearDown(() => bloc.close());

  testWidgets('shows "Accepter l\'offre" title when not checkout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Accepter l\'offre'), findsOneWidget);
  });

  testWidgets('shows "Payer en escrow" title when isCheckout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isCheckout: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Payer en escrow'), findsOneWidget);
  });

  testWidgets('shows "Tu reçois" label for traveler', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Tu reçois'), findsOneWidget);
  });

  testWidgets('shows "Montant à régler" label for sender', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: false));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Montant à régler'), findsOneWidget);
  });

  testWidgets('ne montre PAS le détail commission à l\'expéditeur (jamais le net)',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(bloc: bloc, isTraveler: false, grossPriceEur: 39.20),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('commission Dony'), findsNothing);
  });

  testWidgets('does NOT show commission breakdown for traveler',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(bloc: bloc, isTraveler: true, grossPriceEur: 39.20),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('commission Dony'), findsNothing);
  });

  testWidgets('confirms button label uses Confirmer when not checkout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirmer'), findsOneWidget);
  });

  testWidgets('confirms button label uses Payer (amount) when isCheckout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isCheckout: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    // The button text contains the amount, not just "Payer"
    expect(find.textContaining('Payer ('), findsOneWidget);
  });

  testWidgets('no error when NegotiationLoading state',
      (tester) async {
    when(() => bloc.state).thenReturn(const NegotiationLoading());
    when(() => bloc.stream).thenAnswer(
        (_) => Stream.value(const NegotiationLoading()));
    await tester.pumpWidget(_buildApp(bloc: bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump(const Duration(milliseconds: 500));
    // Sheet rendered without error - button is present
    expect(find.byType(ElevatedButton), findsWidgets);
  });

  testWidgets('traveler sees correct info text', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('l\'expéditeur effectuera le paiement'),
        findsOneWidget);
  });

  testWidgets('sender sees escrow info text', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: false));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('mis en escrow'), findsOneWidget);
  });

  // ── Checkout Stripe réussi → DonySuccessScreen ─────────────────────────

  group('Acceptation offre cash (non-checkout)', () {
    late _MockLocalAuthService authService;
    late _MockBox userPrefsBox;

    setUpAll(() {
      registerFallbackValue(const NegotiationAcceptRequested(threadId: 't-1'));
    });

    setUp(() {
      authService = _MockLocalAuthService();
      userPrefsBox = _MockBox();
      when(() => userPrefsBox.get(HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'))).thenReturn(true);
      when(() => authService.isBiometricAvailable())
          .thenAnswer((_) async => true);
      when(() => authService.authenticateWithBiometric())
          .thenAnswer((_) async => true);

      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      getIt.registerFactory<LocalAuthService>(() => authService);

      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
      getIt.registerFactory<HiveService>(() => _FakeHiveService(userPrefsBox));
    });

    tearDown(() {
      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
    });

    testWidgets(
        'affiche DonySuccessScreen "Accord confirmé !" et dispatch '
        'NegotiationAcceptRequested quand isCheckout: false',
        (tester) async {
      await tester.pumpWidget(_buildApp(bloc: bloc, isCheckout: false));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // Tap le bouton pour accepter l'offre
      await tester.tap(find.textContaining('Confirmer ('));
      // Attend l'authentification biométrique
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // Vérifie que le DonySuccessScreen est affiché avec les implications
      // du paiement en espèces.
      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Accord confirmé !'), findsOneWidget);

      // Vérifie que NegotiationAcceptRequested a été envoyé
      verify(() => bloc.add(any(
              that: isA<NegotiationAcceptRequested>()
                  .having((e) => e.threadId, 'threadId', 't-1'))))
          .called(1);
    });
  });

  group('Paiement checkout Stripe réussi', () {
    late _MockLocalAuthService authService;
    late _MockBox userPrefsBox;
    late _MockPaymentGateway paymentGateway;
    late _MockPaymentRepository paymentRepository;
    late _MockNegotiationRepository negotiationRepository;

    setUpAll(() {
      registerFallbackValue(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_test',
      ));
    });

    setUp(() {
      authService = _MockLocalAuthService();
      userPrefsBox = _MockBox();
      // Biométrie activée + réussie → requirePaymentAuth ne passe jamais par
      // l'écran PIN '/auth/local' (pas de route stub nécessaire).
      when(() => userPrefsBox.get(HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'))).thenReturn(true);
      when(() => authService.isBiometricAvailable())
          .thenAnswer((_) async => true);
      when(() => authService.authenticateWithBiometric())
          .thenAnswer((_) async => true);

      paymentGateway = _MockPaymentGateway();
      // PlatformPayButton (Apple/Google Pay) plante hors iOS/Android réel —
      // on désactive le wallet et paie via PayPal (bouton Flutter classique).
      when(() => paymentGateway.isPlatformPaySupported())
          .thenAnswer((_) async => false);
      when(() => paymentGateway.confirmPayPal(any()))
          .thenAnswer((_) async {});

      paymentRepository = _MockPaymentRepository();
      when(() => paymentRepository.listSavedPaymentMethods())
          .thenAnswer((_) async => []);

      negotiationRepository = _MockNegotiationRepository();
      when(() => negotiationRepository.initiatePayment('t-1')).thenAnswer(
        (_) async => (
          clientSecret: 'pi_test_secret',
          paymentIntentId: 'pi_test',
          amountEur: 35.0,
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
      getIt.registerFactory<NegotiationRepository>(
          () => negotiationRepository);
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
                    onPressed: () => AcceptOfferBottomSheet.show(
                      ctx,
                      bloc: bloc,
                      threadId: 't-1',
                      priceEur: 35.0,
                      isCheckout: true,
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
      return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
    }

    testWidgets(
        'onSuccess du paiement checkout → NegotiationCheckoutRequested + '
        'DonySuccessScreen puis CTA vers /negotiations/{threadId}',
        (tester) async {
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
      await tester.tap(find.textContaining('Payer ('));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // La DonyPaymentSheet est ouverte (PayPal dispo, aucune carte
      // enregistrée) → on paie via le bouton PayPal.
      expect(find.byKey(const Key('paymentSheetPayPalButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('paymentSheetPayPalButton')));
      await tester.pump(); // PaymentSheetProcessing
      await tester.pump(); // PaymentSheetSuccess (résolution async du gateway)
      await tester
          .pump(const Duration(milliseconds: 900)); // déclenchement onSuccess
      // Laisse l'animation de fermeture de la sheet extérieure se terminer —
      // toujours pas de pumpAndSettle, même raison que ci-dessus.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      verify(() => bloc.add(any(
              that: isA<NegotiationCheckoutRequested>()
                  .having((e) => e.threadId, 'threadId', 't-1')
                  .having((e) => e.paymentIntentId, 'paymentIntentId',
                      'pi_test'))))
          .called(1);

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Offre acceptée et payée !'), findsOneWidget);

      await tester.tap(find.text('Voir le suivi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Fil de négociation t-1'), findsOneWidget);
    });
  });
}
