import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectOnboardingBloc
    extends MockBloc<ConnectOnboardingEvent, ConnectOnboardingState>
    implements ConnectOnboardingBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

/// Duration long enough to let all flutter_animate delays complete.
const _kSettle = Duration(milliseconds: 600);

UserModel _buildUser({required String kycStatus}) => UserModel(
      id: 'user-1',
      roles: const ['ROLE_TRAVELER'],
      kycStatus: kycStatus,
      status: 'ACTIVE',
    );

Widget _wrap(ConnectOnboardingBloc bloc, AuthBloc authBloc) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider<ConnectOnboardingBloc>.value(value: bloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: const ConnectOnboardingIntroScreen(),
          ),
        ),
        GoRoute(
          path: '/connect/onboarding/pending',
          builder: (_, __) => const Scaffold(body: Text('Pending')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/kyc/verify',
          builder: (_, __) => const Scaffold(body: Text('Kyc')),
        ),
      ],
    ),
  );
}

void main() {
  late MockConnectOnboardingBloc mockBloc;
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(const ConnectOnboardingLinkRequested());
  });

  setUp(() {
    mockBloc = MockConnectOnboardingBloc();
    whenListen<ConnectOnboardingState>(
      mockBloc,
      Stream.value(const ConnectOnboardingNeedsOnboarding()),
      initialState: const ConnectOnboardingNeedsOnboarding(),
    );

    mockAuthBloc = MockAuthBloc();
    whenListen<AuthState>(
      mockAuthBloc,
      Stream.value(AuthAuthenticated(_buildUser(kycStatus: 'VERIFIED'))),
      initialState: AuthAuthenticated(_buildUser(kycStatus: 'VERIFIED')),
    );
  });

  group('ConnectOnboardingIntroScreen', () {
    testWidgets('renders intro content with CTA button', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      expect(find.text('Compte Stripe Connect'), findsOneWidget);
      expect(find.text('Compléter mon compte'), findsOneWidget);
    });

    testWidgets(
        'dispatches ConnectOnboardingStatusRequested on init so an already-complete '
        'account is detected instead of showing the stale "Complète ton compte" intro',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      verify(() => mockBloc.add(const ConnectOnboardingStatusRequested()))
          .called(1);
    });

    testWidgets(
        'shows the connected confirmation in place, without redirecting, when the '
        'status check resolves to already complete '
        '(regression: the screen never re-checked status on load, so a completed '
        'account still saw the onboarding intro until the button was tapped again; '
        'the fix must not bounce the user to /home either — they came to check this '
        'screen and should see the confirmation here)',
        (tester) async {
      whenListen<ConnectOnboardingState>(
        mockBloc,
        Stream.value(const ConnectOnboardingComplete()),
        initialState: const ConnectOnboardingComplete(),
      );

      final stripeBloc = MockStripeAccountBloc();
      when(() => stripeBloc.add(const StripeAccountStatusRefreshed()))
          .thenReturn(null);
      getIt.registerLazySingleton<StripeAccountBloc>(() => stripeBloc);
      addTearDown(getIt.reset);

      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsNothing);
      expect(find.text('Compte Stripe Connect'), findsOneWidget);
      expect(find.text('Compte Stripe\nconnecté'), findsOneWidget);
      expect(find.text('Compléter mon compte'), findsNothing);
      verify(() => stripeBloc.add(const StripeAccountStatusRefreshed()))
          .called(1);
    });

    testWidgets('shows loading when state is ConnectOnboardingLoading',
        (tester) async {
      whenListen<ConnectOnboardingState>(
        mockBloc,
        Stream.value(const ConnectOnboardingLoading()),
        initialState: const ConnectOnboardingLoading(),
      );

      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      // Button should be disabled (no tap handler)
      final button = tester.widget<InkWell>(
        find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
      );
      expect(button.onTap, isNull);
    });

    testWidgets('shows error banner when state is ConnectOnboardingError',
        (tester) async {
      whenListen<ConnectOnboardingState>(
        mockBloc,
        Stream.value(ConnectOnboardingError(NetworkException('Stripe indisponible'))),
        initialState:
            ConnectOnboardingError(NetworkException('Stripe indisponible')),
      );

      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      // L'écran affiche ErrorPresenter.resolve(error).message → texte du catalog.
      expect(
        find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('dispatches ConnectOnboardingLinkRequested on button tap',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.tap(find.text('Compléter mon compte'));
      await tester.pump(_kSettle);

      verify(() => mockBloc.add(const ConnectOnboardingLinkRequested()))
          .called(1);
    });

    testWidgets(
        'recognizes a verified KYC from AuthProfileUpdated, not just AuthAuthenticated '
        '(regression: reading only AuthAuthenticated missed the state emitted after a '
        'profile edit, wrongly showing the KYC warning banner for an already-verified user)',
        (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        Stream.value(AuthProfileUpdated(_buildUser(kycStatus: 'VERIFIED'))),
        initialState: AuthProfileUpdated(_buildUser(kycStatus: 'VERIFIED')),
      );

      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      expect(find.text('Identité à vérifier'), findsNothing);

      final button = tester.widget<InkWell>(
        find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
      );
      expect(button.onTap, isNotNull);
    });

    testWidgets(
        'shows KYC warning banner and disables CTA when identity is not verified',
        (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        Stream.value(AuthAuthenticated(_buildUser(kycStatus: 'NOT_STARTED'))),
        initialState:
            AuthAuthenticated(_buildUser(kycStatus: 'NOT_STARTED')),
      );

      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      expect(find.text('Identité à vérifier'), findsOneWidget);
      expect(find.text('Vérifier mon identité'), findsOneWidget);

      final button = tester.widget<InkWell>(
        find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
      );
      expect(button.onTap, isNull);
    });

    testWidgets('navigates to /kyc/verify when tapping the banner action',
        (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        Stream.value(AuthAuthenticated(_buildUser(kycStatus: 'NOT_STARTED'))),
        initialState:
            AuthAuthenticated(_buildUser(kycStatus: 'NOT_STARTED')),
      );

      await tester.pumpWidget(_wrap(mockBloc, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.ensureVisible(find.text('Vérifier mon identité'));
      await tester.tap(find.text('Vérifier mon identité'));
      await tester.pumpAndSettle();

      expect(find.text('Kyc'), findsOneWidget);
    });
  });
}
