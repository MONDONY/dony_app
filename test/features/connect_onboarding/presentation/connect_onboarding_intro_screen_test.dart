import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
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

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// L'écran lit aussi `AuthBloc` : Stripe Connect exige une identité vérifiée,
/// et sans elle l'écran cède la place à `IdentityRequiredView`.
AuthBloc _authBloc({String kycStatus = 'VERIFIED'}) {
  final bloc = MockAuthBloc();
  final state = AuthAuthenticated(
    UserModel(
      id: 'u1',
      roles: const ['TRAVELER'],
      kycStatus: kycStatus,
      status: 'ACTIVE',
    ),
  );
  whenListen<AuthState>(bloc, Stream.value(state), initialState: state);
  return bloc;
}

/// Duration long enough to let all flutter_animate delays complete.
const _kSettle = Duration(milliseconds: 600);

/// L'écran lit `StripeAccountBloc` pour savoir si Stripe couvre le pays.
/// Fourni à l'échelle de l'application dans `app.dart`, il doit donc l'être
/// aussi ici.
StripeAccountBloc _stripeBloc({bool connectAvailable = true}) {
  final bloc = MockStripeAccountBloc();
  final state = StripeAccountReady(
    ConnectAccountStatus(
      status: 'NOT_CREATED',
      connectAvailableInCountry: connectAvailable,
    ),
  );
  whenListen<StripeAccountState>(
    bloc,
    Stream.value(state),
    initialState: state,
  );
  return bloc;
}

Widget _wrap(
  ConnectOnboardingBloc bloc, {
  StripeAccountBloc? stripeBloc,
  AuthBloc? authBloc,
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<ConnectOnboardingBloc>.value(value: bloc),
              BlocProvider<StripeAccountBloc>.value(
                value: stripeBloc ?? _stripeBloc(),
              ),
              BlocProvider<AuthBloc>.value(value: authBloc ?? _authBloc()),
            ],
            child: const ConnectOnboardingIntroScreen(),
          ),
        ),
        GoRoute(
          path: '/connect/onboarding/pending',
          builder: (_, _) => const Scaffold(body: Text('Pending')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    ),
  );
}

void main() {
  late MockConnectOnboardingBloc mockBloc;

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
  });

  group('ConnectOnboardingIntroScreen', () {
    testWidgets('renders intro content with CTA button', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(_kSettle);

      expect(find.text('Compte Stripe Connect'), findsOneWidget);
      expect(find.text('Compléter mon compte'), findsOneWidget);
    });

    testWidgets('shows loading when state is ConnectOnboardingLoading', (
      tester,
    ) async {
      whenListen<ConnectOnboardingState>(
        mockBloc,
        Stream.value(const ConnectOnboardingLoading()),
        initialState: const ConnectOnboardingLoading(),
      );

      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(_kSettle);

      // Button should be disabled (no tap handler)
      final button = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(DonyButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(button.onTap, isNull);
    });

    testWidgets('shows error banner when state is ConnectOnboardingError', (
      tester,
    ) async {
      whenListen<ConnectOnboardingState>(
        mockBloc,
        Stream.value(
          const ConnectOnboardingError(NetworkException('Stripe indisponible')),
        ),
        initialState: const ConnectOnboardingError(
          NetworkException('Stripe indisponible'),
        ),
      );

      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(_kSettle);

      // L'écran affiche ErrorPresenter.resolve(error).message → texte du catalog.
      expect(
        find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('dispatches ConnectOnboardingLinkRequested on button tap', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump(_kSettle);

      await tester.tap(find.text('Compléter mon compte'));
      await tester.pump(_kSettle);

      verify(
        () => mockBloc.add(const ConnectOnboardingLinkRequested()),
      ).called(1);
    });

    testWidgets(
      'pays non couvert par Stripe : explique au lieu de proposer l\'onboarding',
      (tester) async {
        await tester.pumpWidget(
          _wrap(mockBloc, stripeBloc: _stripeBloc(connectAvailable: false)),
        );
        await tester.pump(_kSettle);

        expect(
          find.text('Pas encore disponible\ndans votre pays'),
          findsOneWidget,
        );
        expect(find.text('Compléter mon compte'), findsNothing);
        expect(find.byType(DonyButton), findsNothing);
      },
    );

    testWidgets('pays couvert : le parcours d\'onboarding reste proposé', (
      tester,
    ) async {
      // _stripeBloc() rend un pays couvert par défaut.
      await tester.pumpWidget(_wrap(mockBloc, stripeBloc: _stripeBloc()));
      await tester.pump(_kSettle);

      expect(find.text('Compléter mon compte'), findsOneWidget);
      expect(find.text('Pas encore disponible\ndans votre pays'), findsNothing);
    });
  });

  group('garde identité — Stripe Connect exige une identité vérifiée', () {
    // Sept points d'entrée de l'app mènent à cet écran (publication, détail
    // d'annonce, étape prix, feuilles de blocage, compte désactivé,
    // notification push, retour de lien Stripe). Le serveur les refuse tous
    // par un 422 `kyc-required` ; sans cette garde, l'utilisateur ne récolte
    // qu'une erreur brute au lieu d'être conduit à la vérification.
    for (final status in const ['NOT_STARTED', 'PENDING', 'REJECTED']) {
      testWidgets('identité $status : l\'onboarding Connect est remplacé par '
          'l\'invitation à vérifier son identité', (tester) async {
        final bloc = MockConnectOnboardingBloc();
        whenListen<ConnectOnboardingState>(
          bloc,
          const Stream<ConnectOnboardingState>.empty(),
          initialState: const ConnectOnboardingInitial(),
        );

        await tester.pumpWidget(
          _wrap(bloc, authBloc: _authBloc(kycStatus: status)),
        );
        await tester.pump(_kSettle);

        expect(find.text('Vérifier mon identité'), findsOneWidget);
        // Le bouton qui déclencherait la création du compte a disparu.
        expect(find.text('Commencer'), findsNothing);
      });
    }

    testWidgets('identité vérifiée : l\'onboarding Connect s\'affiche '
        'normalement', (tester) async {
      final bloc = MockConnectOnboardingBloc();
      whenListen<ConnectOnboardingState>(
        bloc,
        const Stream<ConnectOnboardingState>.empty(),
        initialState: const ConnectOnboardingInitial(),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(_kSettle);

      expect(find.text('Vérifier mon identité'), findsNothing);
      expect(find.byType(DonyButton), findsWidgets);
    });
  });
}
