import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class MockConfigBloc extends MockBloc<ConfigEvent, ConfigState>
    implements ConfigBloc {}

class MockLocalAuthService extends Mock implements LocalAuthService {}


final _testBid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 5.0,
  pricePerKg: 6.0,
  declaredValueEur: 100.0,
  description: 'Vêtements',
  status: 'ACCEPTED',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2025, 6, 1),
  createdAt: DateTime(2025, 5, 1),
  updatedAt: DateTime(2025, 5, 1),
);

Widget _wrap(Widget child, PaymentBloc bloc, {ConfigBloc? configBloc}) {
  return MaterialApp.router(
    routerConfig: GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<PaymentBloc>.value(value: bloc),
            if (configBloc != null)
              BlocProvider<ConfigBloc>.value(value: configBloc),
          ],
          child: child,
        ),
      ),
    ]),
  );
}

void main() {
  late MockPaymentBloc mockBloc;
  late MockLocalAuthService mockLocalAuth;

  late MockConfigBloc mockConfigBloc;

  setUpAll(() {
    registerFallbackValue(const PaymentInitiated('fallback'));
    registerFallbackValue(const ConfigCommissionRateRequested());
  });

  setUp(() {
    mockBloc = MockPaymentBloc();
    mockConfigBloc = MockConfigBloc();
    mockLocalAuth = MockLocalAuthService();
    whenListen<PaymentState>(
      mockBloc,
      Stream.value(const PaymentInitial()),
      initialState: const PaymentInitial(),
    );
    whenListen<ConfigState>(
      mockConfigBloc,
      Stream.value(const ConfigLoaded(0.12)),
      initialState: const ConfigLoaded(0.12),
    );
    when(() => mockLocalAuth.isBiometricAvailable()).thenAnswer((_) async => true);
  });

  group('PaymentScreen biometric gate', () {
    testWidgets('does NOT dispatch PaymentInitiated when biometric fails', (
      tester,
    ) async {
      when(() => mockLocalAuth.authenticateWithBiometric())
          .thenAnswer((_) async => false);

      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
          ),
          mockBloc,
          configBloc: mockConfigBloc,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Payer 30.00 €'));
      await tester.pumpAndSettle();

      verify(() => mockLocalAuth.authenticateWithBiometric()).called(1);
      verifyNever(() => mockBloc.add(any()));
    });

    testWidgets('dispatches PaymentInitiated after successful biometric', (
      tester,
    ) async {
      when(() => mockLocalAuth.authenticateWithBiometric())
          .thenAnswer((_) async => true);

      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
          ),
          mockBloc,
          configBloc: mockConfigBloc,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Payer 30.00 €'));
      await tester.pumpAndSettle();

      verify(() => mockLocalAuth.authenticateWithBiometric()).called(1);
      verify(() => mockBloc.add(PaymentInitiated('bid-1'))).called(1);
    });

    testWidgets('shows error snackbar when biometric fails', (tester) async {
      when(() => mockLocalAuth.authenticateWithBiometric())
          .thenAnswer((_) async => false);

      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            bid: _testBid,
            localAuthService: mockLocalAuth,
          ),
          mockBloc,
          configBloc: mockConfigBloc,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Payer 30.00 €'));
      await tester.pumpAndSettle();

      expect(find.text('Authentification requise'), findsOneWidget);
    });
  });
}
