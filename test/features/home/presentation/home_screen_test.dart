import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// ─── Helpers ──────────────────────────────────────────────────────────────────

UserModel _makeUser({List<String> roles = const ['ROLE_SENDER']}) => UserModel(
      id: 'uid-1',
      phoneNumber: '+33600000000',
      firstName: 'Ibrahima',
      lastName: 'Diallo',
      roles: roles,
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

GoRouter _buildRouter(AuthBloc authBloc) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const Scaffold(body: Text('Search')),
        ),
        GoRoute(
          path: '/announcements/create',
          builder: (_, __) => const Scaffold(body: Text('Create Announcement')),
        ),
        GoRoute(
          path: '/messages',
          builder: (_, __) => const Scaffold(body: Text('Messages')),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, AuthBloc authBloc) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _buildRouter(authBloc),
    ),
  );
  // Allow flutter_animate animations to settle
  await tester.pump(const Duration(milliseconds: 600));
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    mockAuthBloc.close();
  });

  group('HomeScreen — Sender view (ROLE_SENDER)', () {
    setUp(() {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(_makeUser(roles: ['ROLE_SENDER'])));
    });

    testWidgets('renders sender headline text', (tester) async {
      await _pump(tester, mockAuthBloc);

      // "on envoie quoi" is a TextSpan inside Text.rich — textContaining works
      expect(find.textContaining('on envoie quoi'), findsOneWidget);
    });

    testWidgets('renders "Trouver un voyageur" CTA button', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('Trouver un voyageur'), findsOneWidget);
      expect(find.byType(DonyButton), findsAtLeastNWidgets(1));
    });

    testWidgets('renders greeting with first name', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.textContaining('Bonjour Ibrahima'), findsOneWidget);
    });

    testWidgets('renders corridors section header', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('CORRIDORS POPULAIRES'), findsOneWidget);
    });

    testWidgets('renders 4 corridor chips', (tester) async {
      await _pump(tester, mockAuthBloc);

      // Each corridor has its code as a text widget
      expect(find.text('PAR → DKR'), findsOneWidget);
      expect(find.text('LYS → ABJ'), findsOneWidget);
      expect(find.text('MRS → BKO'), findsOneWidget);
      expect(find.text('PAR → DLA'), findsOneWidget);
    });

    testWidgets('HOT badge appears only on first corridor', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('HOT'), findsOneWidget);
    });

    testWidgets('renders Garantie Dony card', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('Garantie Dony'), findsOneWidget);
    });

    testWidgets('does NOT render traveler-specific text in sender view',
        (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('CE MOIS-CI'), findsNothing);
      expect(find.text('Publier un trajet'), findsNothing);
    });
  });

  group('HomeScreen — Traveler view (ROLE_TRAVELER)', () {
    setUp(() {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(_makeUser(roles: ['ROLE_TRAVELER'])));
    });

    testWidgets('renders "CE MOIS-CI" stats label', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('CE MOIS-CI'), findsOneWidget);
    });

    testWidgets('renders "Publier un trajet" CTA button', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('Publier un trajet'), findsOneWidget);
      expect(find.byType(DonyButton), findsAtLeastNWidgets(1));
    });

    testWidgets('renders earnings amount', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.textContaining('248,50'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders active trips section label', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('MES TRAJETS ACTIFS'), findsOneWidget);
    });

    testWidgets('renders payout footer', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.textContaining('Prochain payout'), findsOneWidget);
    });

    testWidgets('does NOT render sender CTA in traveler view', (tester) async {
      await _pump(tester, mockAuthBloc);

      expect(find.text('Trouver un voyageur'), findsNothing);
    });
  });

  group('HomeScreen — Unauthenticated / unknown role falls back to sender view',
      () {
    testWidgets('shows sender view when auth state is AuthInitial',
        (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await _pump(tester, mockAuthBloc);

      // Fallback to sender view — headline present
      expect(find.textContaining('on envoie quoi'), findsOneWidget);
      expect(find.text('CE MOIS-CI'), findsNothing);
    });
  });
}
