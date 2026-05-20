import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/traveler_upgrade_bloc.dart';
import 'package:dony/features/profile/presentation/screens/become_traveler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockTravelerUpgradeBloc
    extends MockBloc<TravelerUpgradeEvent, TravelerUpgradeState>
    implements TravelerUpgradeBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _kSettle = Duration(milliseconds: 600);

UserModel _userWith({
  String kycStatus = 'NOT_STARTED',
  String stripeStatus = 'NOT_CREATED',
  List<String> roles = const ['SENDER'],
}) =>
    UserModel(
      id: 'user-1',
      kycStatus: kycStatus,
      stripeAccountStatus: stripeStatus,
      status: 'ACTIVE',
      roles: roles,
    );

Widget _wrap({
  required MockTravelerUpgradeBloc upgradeBloc,
  required MockAuthBloc authBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<TravelerUpgradeBloc>.value(value: upgradeBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const BecomeATravelerScreen(),
          ),
          GoRoute(
            path: '/profile/help/contact',
            builder: (_, _) => const Scaffold(body: Text('Contact')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const TravelerUpgradeActivateRequested());
    registerFallbackValue(const TravelerUpgradeDeactivateRequested());
    registerFallbackValue(AuthUserSynced(_userWith()));
  });

  late MockTravelerUpgradeBloc upgradeBloc;
  late MockAuthBloc authBloc;

  setUp(() {
    upgradeBloc = MockTravelerUpgradeBloc();
    authBloc = MockAuthBloc();
    whenListen<TravelerUpgradeState>(
      upgradeBloc,
      const Stream.empty(),
      initialState: const TravelerUpgradeInitial(),
    );
  });

  group('BecomeATravelerScreen — visibilité bouton activation', () {
    testWidgets(
        'bouton activation NON affiché quand kycStatus != VERIFIED',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          stripeStatus: 'ONBOARDING_COMPLETE',
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(find.text('Activer mon compte voyageur'), findsNothing);
    });

    testWidgets(
        'bouton activation NON affiché quand stripeStatus != ONBOARDING_COMPLETE',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(find.text('Activer mon compte voyageur'), findsNothing);
    });

    testWidgets(
        'bouton activation AFFICHÉ quand KYC=VERIFIED et Stripe=ONBOARDING_COMPLETE et pas TRAVELER',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(find.text('Activer mon compte voyageur'), findsOneWidget);
      expect(find.text('Désactiver mon compte voyageur'), findsNothing);
    });
  });

  group('BecomeATravelerScreen — bouton désactivation', () {
    testWidgets(
        'bouton désactivation AFFICHÉ quand user a le rôle TRAVELER',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
          roles: const ['SENDER', 'TRAVELER'],
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(find.text('Désactiver mon compte voyageur'), findsOneWidget);
      expect(find.text('Activer mon compte voyageur'), findsNothing);
    });

    testWidgets(
        '_PendingHint NON affiché quand isTraveler = true',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
          roles: const ['SENDER', 'TRAVELER'],
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(
        find.text(
          'Complétez les étapes ci-dessus pour activer votre compte voyageur.',
        ),
        findsNothing,
      );
    });

    testWidgets(
        'dispatch TravelerUpgradeDeactivateRequested au tap du bouton désactivation',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
          roles: const ['SENDER', 'TRAVELER'],
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      final deactivateBtn = find.text('Désactiver mon compte voyageur');
      await tester.ensureVisible(deactivateBtn);
      await tester.pumpAndSettle();
      await tester.tap(deactivateBtn);
      await tester.pump();

      verify(
        () => upgradeBloc.add(const TravelerUpgradeDeactivateRequested()),
      ).called(1);
    });
  });

  group('BecomeATravelerScreen — état loading', () {
    testWidgets(
        'affiche CircularProgressIndicator pendant TravelerUpgradeLoading (utilisateur TRAVELER)',
        (tester) async {
      whenListen<TravelerUpgradeState>(
        upgradeBloc,
        const Stream.empty(),
        initialState: const TravelerUpgradeLoading(),
      );
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
          roles: const ['SENDER', 'TRAVELER'],
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Désactiver mon compte voyageur'), findsNothing);
    });

    testWidgets(
        'affiche CircularProgressIndicator pendant TravelerUpgradeLoading (utilisateur non TRAVELER)',
        (tester) async {
      whenListen<TravelerUpgradeState>(
        upgradeBloc,
        const Stream.empty(),
        initialState: const TravelerUpgradeLoading(),
      );
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Activer mon compte voyageur'), findsNothing);
    });
  });

  group('BecomeATravelerScreen — _PendingHint', () {
    testWidgets('_PendingHint affiché quand canActivate = false', (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith()),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(
        find.text(
          'Complétez les étapes ci-dessus pour activer votre compte voyageur.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('_PendingHint NON affiché quand canActivate = true et pas TRAVELER',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      expect(
        find.text(
          'Complétez les étapes ci-dessus pour activer votre compte voyageur.',
        ),
        findsNothing,
      );
    });
  });

  group('BecomeATravelerScreen — dispatch événement activation', () {
    testWidgets(
        'dispatch TravelerUpgradeActivateRequested au tap du bouton activation',
        (tester) async {
      whenListen<AuthState>(
        authBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(
          kycStatus: 'VERIFIED',
          stripeStatus: 'ONBOARDING_COMPLETE',
        )),
      );

      await tester.pumpWidget(_wrap(
        upgradeBloc: upgradeBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_kSettle);

      final activateBtn = find.text('Activer mon compte voyageur');
      await tester.ensureVisible(activateBtn);
      await tester.pumpAndSettle();
      await tester.tap(activateBtn);
      await tester.pump();

      verify(() => upgradeBloc.add(const TravelerUpgradeActivateRequested()))
          .called(1);
    });
  });
}
