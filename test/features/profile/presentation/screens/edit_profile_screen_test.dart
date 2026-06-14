import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _senderUser = UserModel(
  id: 'user-sender',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  email: 'ibra@test.com',
  city: 'Paris',
  bio: 'Expéditeur depuis 2022.',
  birthDate: DateTime(1990, 6, 15),
  roles: const ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
  languages: const [],
);

final _travelerUser = UserModel(
  id: 'user-traveler',
  firstName: 'Moussa',
  lastName: 'Koné',
  email: 'moussa@test.com',
  city: 'Lyon',
  roles: const ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  languages: const ['Français', 'Wolof'],
  transportMode: 'AVION',
);

// ── Test harness ──────────────────────────────────────────────────────────────

Widget _wrap(Widget child, MockAuthBloc authBloc) {
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => child),
        ],
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
  });

  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
  });

  tearDown(() {
    mockAuthBloc.close();
  });

  // ── Test 1 : rendu de base — champs + bouton sticky ───────────────────────

  testWidgets('EditProfileScreen rend les champs + bouton sticky', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le profil'), findsOneWidget);
    // _SectionLabel renders toUpperCase
    expect(find.text('À PROPOS'), findsOneWidget);
    expect(find.widgetWithText(DonyButton, 'Enregistrer'), findsOneWidget);
    // Sticky button must NOT be inside the scrollable content
    // (it should be in bottomNavigationBar, not inside SingleChildScrollView)
    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    final buttonInScroll = find.descendant(
      of: scrollView,
      matching: find.widgetWithText(DonyButton, 'Enregistrer'),
    );
    expect(buttonInScroll, findsNothing);
  });

  // ── Test 2 : voyageur voit "Préférences" / langues ────────────────────────

  testWidgets('voyageur voit la section Préférences avec les langues', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_travelerUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pumpAndSettle();

    // _SectionLabel renders toUpperCase
    expect(find.text('PRÉFÉRENCES'), findsOneWidget);
    expect(find.text('Langues parlées'), findsOneWidget);
    expect(find.text('Mode de transport'), findsOneWidget);
    // Language chips should be present
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Wolof'), findsOneWidget);
  });

  // ── Test 3 : non-voyageur ne voit PAS "Préférences" ──────────────────────

  testWidgets('non-voyageur ne voit pas la section Préférences', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pumpAndSettle();

    expect(find.text('PRÉFÉRENCES'), findsNothing);
    expect(find.text('Langues parlées'), findsNothing);
    expect(find.text('Mode de transport'), findsNothing);
  });

  // ── Test 4 : pré-remplit les champs depuis AuthAuthenticated ──────────────

  testWidgets('pré-remplit les champs depuis AuthAuthenticated', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pumpAndSettle();

    final editableTexts = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((e) => e.controller.text)
        .toList();

    expect(editableTexts, contains('Ibrahima'));
    expect(editableTexts, contains('Diallo'));
    expect(editableTexts, contains('ibra@test.com'));
    expect(editableTexts, contains('Paris'));
    expect(editableTexts, contains('Expéditeur depuis 2022.'));
    expect(find.text('15/06/1990'), findsOneWidget);
  });

  // ── Test 5 : dispatche AuthUpdateProfileRequested au tap Enregistrer ──────

  testWidgets('dispatche AuthUpdateProfileRequested au tap sur Enregistrer', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pump();

    verify(
      () => mockAuthBloc.add(any(that: isA<AuthUpdateProfileRequested>())),
    ).called(1);
  });

  // ── Test 6 : pop(true) sur AuthProfileUpdated ─────────────────────────────

  testWidgets('pops (retourne) après AuthProfileUpdated', (tester) async {
    // Start with AuthAuthenticated, then emit AuthProfileUpdated.
    // The screen must pop, which causes it to be removed from the widget tree.
    whenListen<AuthState>(
      mockAuthBloc,
      Stream.value(AuthProfileUpdated(_senderUser)),
      initialState: AuthAuthenticated(_senderUser),
    );

    // Navigate to /edit on top of /, so there is something to pop back to.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, __) => BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const EditProfileScreen(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Push /edit on top of /
    router.push('/edit');
    await tester.pumpAndSettle();

    // The stream was set up to immediately emit AuthProfileUpdated →
    // BlocListener calls context.pop(true) → navigates back.
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  // ── Test 7 : désactive le bouton pendant AuthLoading ─────────────────────

  testWidgets('désactive le bouton pendant AuthLoading', (tester) async {
    // Start with AuthAuthenticated so the user is cached, then emit AuthLoading.
    // The screen should keep showing (lastUser retained) but with isLoading=true.
    whenListen<AuthState>(
      mockAuthBloc,
      Stream.value(const AuthLoading()),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    // First pump renders initial AuthAuthenticated state.
    await tester.pump();
    // Second pump delivers the AuthLoading stream event.
    await tester.pump(const Duration(milliseconds: 100));

    // When isLoading=true, DonyButton shows a spinner (no text label).
    // Find by type and check its onPressed is null.
    final buttons = tester.widgetList<DonyButton>(find.byType(DonyButton));
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
    }
  });
}

