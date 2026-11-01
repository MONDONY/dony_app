import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/commission_grid_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class MockLocalAuthService extends Mock implements LocalAuthService {}

class MockBox extends Mock implements Box {}

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
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

final _testBid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 5.0,
  pricePerKg: 6.0,
  description: 'Vêtements',
  status: 'ACCEPTED',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2025, 6),
  createdAt: DateTime(2025, 5),
  updatedAt: DateTime(2025, 5),
);

/// Wraps the widget under test with a GoRouter that includes /auth/local
/// so that PIN fallback navigation does not throw.
Widget _wrap(
  Widget child,
  PaymentBloc bloc, {
  // When [pinResult] is non-null, /auth/local will pop with that value.
  bool? pinResult,
  String helpConfigJson = _emptyHelpConfigJson,
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<PaymentBloc>.value(value: bloc),
              BlocProvider<HelpCenterBloc>(
                create: (_) => HelpCenterBloc(
                  HelpCenterRepository(
                    _StaticHelpCenterSource(helpConfigJson),
                    fallbackJsonLoader: () async => _emptyHelpConfigJson,
                  ),
                  makeDisabledAnalytics(MockAnalyticsBackend()),
                )..add(const HelpCenterLoadRequested()),
              ),
            ],
            child: child,
          ),
        ),
        // Stub for PIN screen — pops immediately with [pinResult].
        GoRoute(
          path: '/auth/local',
          builder: (context, _) {
            // Use a post-frame callback so we can pop after the frame is built.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.pop(pinResult);
              }
            });
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/profile/help/tutorial/:tutorialId',
          builder: (_, state) => Scaffold(
            body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
          ),
        ),
      ],
    ),
  );
}

/// Creates a [MockBox] that returns [biometricEnabled] for the
/// [HiveService.kBiometricEnabled] key.
MockBox _mockUserPrefs({required bool biometricEnabled}) {
  final box = MockBox();
  when(
    () => box.get(
      HiveService.kBiometricEnabled,
      defaultValue: any(named: 'defaultValue'),
    ),
  ).thenReturn(biometricEnabled);
  return box;
}

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  late MockPaymentBloc mockBloc;
  late MockLocalAuthService mockLocalAuth;

  setUpAll(() {
    registerFallbackValue(const PaymentInitiated('fallback'));
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    // DonySnackbar v2 (#123) déduplique les messages identiques < 400 ms via
    // un cache statique partagé entre les tests — reset pour que chaque test
    // vérifie son propre snackbar.
    DonySnackbar.clearDedup();
    mockBloc = MockPaymentBloc();
    mockLocalAuth = MockLocalAuthService();
    whenListen<PaymentState>(
      mockBloc,
      Stream.value(const PaymentInitial()),
      initialState: const PaymentInitial(),
    );
    when(
      () => mockLocalAuth.isBiometricAvailable(),
    ).thenAnswer((_) async => true);
    // Ces tests portent sur le repli PIN : ils supposent donc un code
    // configuré. Depuis que le PIN est facultatif, `requirePaymentAuth` ne
    // pousse l'écran de saisie que si un code existe.
    when(mockLocalAuth.isPinSet).thenAnswer((_) async => true);
  });

  group('PaymentScreen biometric gate', () {
    testWidgets(
      'does NOT dispatch PaymentInitiated when biometric fails and PIN not entered',
      (tester) async {
        when(
          () => mockLocalAuth.authenticateWithBiometric(),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: _testBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: true),
            ),
            mockBloc,
            pinResult: false, // PIN screen returns false (user cancelled)
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(DonyButton));
        await tester.pumpAndSettle();

        verify(() => mockLocalAuth.authenticateWithBiometric()).called(1);
        verifyNever(() => mockBloc.add(any()));
      },
    );

    testWidgets(
      'récap expéditeur : seul le brut (total + tarif/kg), jamais le net ni la commission',
      (tester) async {
        // bid = 5 kg × 6 €/kg NET. Brut = 30 × 1,12 = 33,60 €. Tarif/kg brut = 6,72.
        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: _testBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: true),
            ),
            mockBloc,
          ),
        );
        await tester.pumpAndSettle();

        // L'expéditeur voit le total brut + le tarif/kg brut.
        expect(
          tester.widget<DonyButton>(find.byType(DonyButton)).label,
          contains('33,60'),
        );
        expect(find.textContaining('33,60'), findsWidgets);
        expect(find.textContaining('6,72'), findsOneWidget);
        expect(find.textContaining('€/kg'), findsOneWidget);
        // Il ne voit JAMAIS le net voyageur (30 €) ni la commission isolée.
        expect(find.textContaining('30,00'), findsNothing);
        expect(find.textContaining('6,00'), findsNothing);
        expect(find.textContaining('Frais de service'), findsNothing);
        expect(find.textContaining('+ 3,60'), findsNothing);
        expect(find.textContaining('+3,60'), findsNothing);
      },
    );

    testWidgets(
      'poids décimal : virgule en français (correction R46, formatOneDecimal)',
      (tester) async {
        final decimalWeightBid = BidModel(
          id: 'bid-decimal-1',
          announcementId: 'ann-1',
          senderId: 'sender-1',
          weightKg: 4.5,
          pricePerKg: 6.0,
          description: 'Vêtements',
          status: 'ACCEPTED',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2025, 6),
          createdAt: DateTime(2025, 5),
          updatedAt: DateTime(2025, 5),
        );

        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: decimalWeightBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: true),
            ),
            mockBloc,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('4,5 kg'), findsOneWidget);
        expect(find.textContaining('4.5 kg'), findsNothing);
      },
    );

    testWidgets('tarif/kg affiché dans la devise du bid, pas toujours en EUR', (
      tester,
    ) async {
      final cadBid = BidModel(
        id: 'bid-cad-1',
        announcementId: 'ann-1',
        senderId: 'sender-1',
        weightKg: 5.0,
        pricePerKg: 6.0,
        description: 'Vêtements',
        status: 'ACCEPTED',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2025, 6),
        createdAt: DateTime(2025, 5),
        updatedAt: DateTime(2025, 5),
        currency: 'CAD',
      );

      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: cadBid,
            localAuthService: mockLocalAuth,
            userPrefs: _mockUserPrefs(biometricEnabled: true),
          ),
          mockBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('CA\$'), findsWidgets);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets('dispatches PaymentInitiated after successful biometric', (
      tester,
    ) async {
      when(
        () => mockLocalAuth.authenticateWithBiometric(),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
            userPrefs: _mockUserPrefs(biometricEnabled: true),
          ),
          mockBloc,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DonyButton));
      await tester.pumpAndSettle();

      verify(() => mockLocalAuth.authenticateWithBiometric()).called(1);
      verify(() => mockBloc.add(const PaymentInitiated('bid-1'))).called(1);
    });

    testWidgets(
      'dispatches PaymentInitiated when biometric fails but PIN succeeds',
      (tester) async {
        when(
          () => mockLocalAuth.authenticateWithBiometric(),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: _testBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: true),
            ),
            mockBloc,
            pinResult: true, // PIN screen returns true (success)
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(DonyButton));
        await tester.pumpAndSettle();

        verify(() => mockLocalAuth.authenticateWithBiometric()).called(1);
        verify(() => mockBloc.add(const PaymentInitiated('bid-1'))).called(1);
      },
    );

    testWidgets(
      'shows error snackbar when biometric fails and PIN returns false',
      (tester) async {
        when(
          () => mockLocalAuth.authenticateWithBiometric(),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: _testBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: true),
            ),
            mockBloc,
            pinResult: false,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(DonyButton));
        await tester.pumpAndSettle();

        expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
      },
    );

    testWidgets('shows error snackbar when toggle OFF and PIN returns false', (
      tester,
    ) async {
      // Toggle OFF → biometric never tried, PIN directly
      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
            userPrefs: _mockUserPrefs(biometricEnabled: false),
          ),
          mockBloc,
          pinResult: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DonyButton));
      await tester.pumpAndSettle();

      verifyNever(() => mockLocalAuth.isBiometricAvailable());
      verifyNever(() => mockLocalAuth.authenticateWithBiometric());
      verifyNever(() => mockBloc.add(any()));
      expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
    });

    testWidgets(
      'dispatches PaymentInitiated when toggle OFF and PIN succeeds',
      (tester) async {
        // Toggle OFF → biometric never tried, PIN directly
        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: _testBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: false),
            ),
            mockBloc,
            pinResult: true,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(DonyButton));
        await tester.pumpAndSettle();

        verifyNever(() => mockLocalAuth.isBiometricAvailable());
        verifyNever(() => mockLocalAuth.authenticateWithBiometric());
        verify(() => mockBloc.add(const PaymentInitiated('bid-1'))).called(1);
      },
    );
  });

  group('PaymentScreen montant payé', () {
    BidModel bidWith({double? totalSenderAmountEur, double pricePerKg = 6.0}) =>
        BidModel(
          id: 'bid-total-1',
          announcementId: 'ann-1',
          senderId: 'sender-1',
          weightKg: 1.0,
          pricePerKg: pricePerKg,
          totalSenderAmountEur: totalSenderAmountEur,
          description: 'Vêtements',
          status: 'ACCEPTED',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2025, 6),
          createdAt: DateTime(2025, 5),
          updatedAt: DateTime(2025, 5),
        );

    Future<String> payLabel(WidgetTester tester, BidModel bid) async {
      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: bid,
            localAuthService: mockLocalAuth,
            userPrefs: _mockUserPrefs(biometricEnabled: true),
          ),
          mockBloc,
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<DonyButton>(find.byType(DonyButton)).label;
    }

    testWidgets('total = totalSenderAmountEur du serveur', (tester) async {
      final label = await payLabel(
        tester,
        bidWith(totalSenderAmountEur: 40.25),
      );
      expect(label, 'Payer ${formatPriceIn(40.25, 'EUR')}');
    });

    testWidgets('sous grille, le total du serveur reste prioritaire', (
      tester,
    ) async {
      useTestCommissionGrid();
      final label = await payLabel(
        tester,
        bidWith(totalSenderAmountEur: 40.25),
      );
      expect(label, 'Payer ${formatPriceIn(40.25, 'EUR')}');
    });

    testWidgets(
      'sans total serveur, sous grille, net 5 € : bouton « Payer 6,00 € »',
      (tester) async {
        // 1 kg × 5 € net : 7 % = 0,35 €, relevé au minimum de 1,00 €.
        useTestCommissionGrid();
        final label = await payLabel(tester, bidWith(pricePerKg: 5));
        expect(label, 'Payer ${formatPriceIn(6.00, 'EUR')}');
        // Jamais l'ancien calcul au taux unique (5 × 1,12 = 5,60).
        expect(label, isNot(contains('5,60')));
      },
    );

    testWidgets('sans total serveur ni grille : taux unique au centime', (
      tester,
    ) async {
      final label = await payLabel(tester, bidWith(pricePerKg: 5));
      expect(label, 'Payer ${formatPriceIn(5.60, 'EUR')}');
    });
  });

  group('PaymentScreen escrow confirmed state', () {
    testWidgets(
      'affiche DonySuccessScreen quand le paiement escrow est confirmé',
      (tester) async {
        whenListen<PaymentState>(
          mockBloc,
          Stream.value(const PaymentEscrowPending(50.0)),
          initialState: const PaymentEscrowPending(50.0),
        );

        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: _testBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: true),
            ),
            mockBloc,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DonySuccessScreen), findsOneWidget);
        expect(find.text('Envoi réservé !'), findsOneWidget);
      },
    );
  });

  group('PaymentScreen en anglais', () {
    testWidgets('titre et bouton de paiement traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
            userPrefs: _mockUserPrefs(biometricEnabled: true),
          ),
          mockBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pay for my shipment'), findsOneWidget);
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton)).label,
        startsWith('Pay '),
      );
    });

    testWidgets('récapitulatif traduit (poids, prix/kg, total)', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
            userPrefs: _mockUserPrefs(biometricEnabled: true),
          ),
          mockBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Price/kg'), findsOneWidget);
      expect(find.text('You pay'), findsOneWidget);
    });

    testWidgets(
      'poids décimal : point en anglais (correction R46, formatOneDecimal)',
      (tester) async {
        useEnglish();
        final decimalWeightBid = BidModel(
          id: 'bid-decimal-en-1',
          announcementId: 'ann-1',
          senderId: 'sender-1',
          weightKg: 4.5,
          pricePerKg: 6.0,
          description: 'Clothes',
          status: 'ACCEPTED',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2025, 6),
          createdAt: DateTime(2025, 5),
          updatedAt: DateTime(2025, 5),
        );

        await tester.pumpWidget(
          _wrap(
            PaymentScreen(
              bid: decimalWeightBid,
              localAuthService: mockLocalAuth,
              userPrefs: _mockUserPrefs(biometricEnabled: true),
            ),
            mockBloc,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('4.5 kg'), findsOneWidget);
        expect(find.textContaining('4,5 kg'), findsNothing);
      },
    );

    testWidgets('vue de confirmation escrow traduite', (tester) async {
      useEnglish();
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentEscrowPending(50.0)),
        initialState: const PaymentEscrowPending(50.0),
      );

      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
            userPrefs: _mockUserPrefs(biometricEnabled: true),
          ),
          mockBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Shipment reserved!'), findsOneWidget);
      expect(find.text('View my shipments'), findsOneWidget);
      expect(find.textContaining('is held and secured'), findsOneWidget);
    });
  });
}
