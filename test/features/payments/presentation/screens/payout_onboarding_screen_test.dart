import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/screens/payout_onboarding_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

const _kUser = UserModel(
  id: 'uid-1',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: ['ROLE_TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

Widget _wrap(
  PaymentBloc bloc, {
  MockAuthBloc? authBloc,
  MockStripeAccountBloc? stripeBloc,
}) {
  final auth = authBloc ?? MockAuthBloc();
  if (authBloc == null) {
    when(() => auth.state).thenReturn(const AuthAuthenticated(_kUser));
    when(() => auth.stream).thenAnswer((_) => const Stream.empty());
  }
  final stripe = stripeBloc ?? MockStripeAccountBloc();
  if (stripeBloc == null) {
    when(() => stripe.state).thenReturn(const StripeAccountInitial());
    when(() => stripe.stream).thenAnswer((_) => const Stream.empty());
    when(() => stripe.isClosed).thenReturn(false);
  }
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<PaymentBloc>.value(value: bloc),
              BlocProvider<StripeAccountBloc>.value(value: stripe),
            ],
            child: const PayoutOnboardingScreen(),
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
  });

  late MockPaymentBloc mockBloc;
  late MockStripeAccountBloc mockStripeBloc;

  setUp(() {
    mockBloc = MockPaymentBloc();
    whenListen<PaymentState>(
      mockBloc,
      Stream.value(const PaymentInitial()),
      initialState: const PaymentInitial(),
    );
    mockStripeBloc = MockStripeAccountBloc();
    when(() => mockStripeBloc.state).thenReturn(const StripeAccountInitial());
    when(() => mockStripeBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockStripeBloc.isClosed).thenReturn(false);
    when(
      () => mockStripeBloc.add(const StripeAccountStatusRefreshed()),
    ).thenReturn(null);
    // Register in GetIt so the listener in PayoutOnboardingScreen can call
    // getIt<StripeAccountBloc>() when PaymentOnboardingComplete fires.
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
    getIt.registerSingleton<StripeAccountBloc>(mockStripeBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<StripeAccountBloc>()) {
      getIt.unregister<StripeAccountBloc>();
    }
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
      expect(find.textContaining('pas terminée'), findsOneWidget);
    });

    testWidgets(
      'le bandeau survit au démontage : il suit le statut serveur, pas le '
      'PaymentBloc recréé à chaque montage',
      (tester) async {
        // PaymentBloc revenu à Initial (nouvelle instance de route), mais le
        // serveur sait que l'inscription est entamée.
        when(() => mockStripeBloc.state).thenReturn(
          const StripeAccountReady(
            ConnectAccountStatus(status: 'PENDING_ONBOARDING'),
          ),
        );

        await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.textContaining('pas terminée'), findsOneWidget);
        expect(find.text('Reprendre mon inscription'), findsOneWidget);
        expect(find.text('Connecter mon compte bancaire'), findsNothing);
      },
    );

    testWidgets('aucun bandeau quand aucun compte n\'a jamais été créé', (
      tester,
    ) async {
      when(() => mockStripeBloc.state).thenReturn(
        const StripeAccountReady(ConnectAccountStatus(status: 'NOT_CREATED')),
      );

      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('pas terminée'), findsNothing);
      expect(find.text('Connecter mon compte bancaire'), findsOneWidget);
    });

    testWidgets('resynchronise le statut à l\'ouverture de l\'écran', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: mockStripeBloc));
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => mockStripeBloc.add(const StripeAccountStatusRefreshed()),
      ).called(1);
    });

    testWidgets('affiche le bandeau error en état error', (tester) async {
      whenListen<PaymentState>(
        mockBloc,
        Stream.value(const PaymentError(NetworkException('Compte refusé'))),
        initialState: const PaymentError(NetworkException('Compte refusé')),
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

    testWidgets('dispatch PaymentConnectAccountRequested au tap', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Connecter mon compte bancaire'));
      await tester.tap(find.text('Connecter mon compte bancaire'));
      verify(
        () => mockBloc.add(const PaymentConnectAccountRequested()),
      ).called(1);
    });
  });
}
