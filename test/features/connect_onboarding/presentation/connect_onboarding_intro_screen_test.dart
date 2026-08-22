import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
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

Widget _wrap(ConnectOnboardingBloc bloc, {StripeAccountBloc? stripeBloc}) {
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

        expect(find.text('Pas encore disponible\ndans votre pays'), findsOneWidget);
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
}
