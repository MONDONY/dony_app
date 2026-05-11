import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

final _kUser = UserModel(
  id: 'uid-1',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: const ['ROLE_TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'NOT_CREATED',
);

Widget _wrap(PaymentBloc bloc, {MockAuthBloc? authBloc}) {
  final auth = authBloc ?? MockAuthBloc();
  if (authBloc == null) {
    when(() => auth.state).thenReturn(AuthAuthenticated(_kUser));
    when(() => auth.stream).thenAnswer((_) => const Stream.empty());
  }
  return MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<PaymentBloc>.value(value: bloc),
          ],
          child: const PayoutOnboardingScreen(),
        ),
      ),
    ]),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(FakeAuthEvent()));

  late MockPaymentBloc mockBloc;

  setUp(() {
    mockBloc = MockPaymentBloc();
    whenListen<PaymentState>(
      mockBloc,
      Stream.value(const PaymentInitial()),
      initialState: const PaymentInitial(),
    );
  });

  group('PayoutOnboardingScreen', () {
    testWidgets('affiche le bouton Connecter en état initial', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Connecter mon compte bancaire'), findsOneWidget);
    });

    testWidgets('affiche le bandeau warning en état pending', (tester) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentOnboardingPending()),
        initialState: const PaymentOnboardingPending(),
      );
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Vérification en cours'), findsOneWidget);
    });

    testWidgets('affiche le bandeau error en état error', (tester) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(PaymentError(NetworkException('Compte refusé'))),
        initialState: PaymentError(NetworkException('Compte refusé')),
      );
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      // L'écran affiche ErrorPresenter.resolve(error).message → texte du catalog.
      expect(
        find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('affiche la vue succès en état complete', (tester) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentOnboardingComplete()),
        initialState: const PaymentOnboardingComplete(),
      );
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paiements activés ✓'), findsOneWidget);
    });

    testWidgets('dispatch PaymentConnectAccountRequested au tap', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Connecter mon compte bancaire'));
      await tester.tap(find.text('Connecter mon compte bancaire'));
      verify(() => mockBloc.add(const PaymentConnectAccountRequested())).called(1);
    });
  });
}
