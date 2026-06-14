import 'dart:async';
import 'dart:io';

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
import 'package:image_picker/image_picker.dart' show XFile;
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
);

const _travelerUser = UserModel(
  id: 'user-traveler',
  firstName: 'Moussa',
  lastName: 'Koné',
  email: 'moussa@test.com',
  city: 'Lyon',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  languages: ['Français', 'Wolof'],
  transportMode: 'AVION',
);

// ── Test harness ──────────────────────────────────────────────────────────────

Widget _wrap(Widget child, MockAuthBloc authBloc) {
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, _) => child),
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
      initialState: const AuthAuthenticated(_travelerUser),
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

  // ── Test 6 : AuthProfileUpdated seul (sans save) ne pop PAS ─────────────
  //
  // Avatar upload also produces AuthProfileUpdated. The screen must stay open.

  testWidgets(
    'ne pop PAS sur AuthProfileUpdated sans save (avatar upload)',
    (tester) async {
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
            builder: (context, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/edit',
            builder: (context, _) => BlocProvider<AuthBloc>.value(
              value: mockAuthBloc,
              child: const EditProfileScreen(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(router.push('/edit'));
      await tester.pumpAndSettle();

      // AuthProfileUpdated was received but _saving is false (no save tap) →
      // the screen must remain open.
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    },
  );

  // ── Test 6b : pop(true) sur AuthProfileUpdated après un save ─────────────

  testWidgets('pops (retourne) après AuthProfileUpdated suite à un save', (
    tester,
  ) async {
    // We need a controller so we can push AuthProfileUpdated after the tap.
    final controller = StreamController<AuthState>();

    whenListen<AuthState>(
      mockAuthBloc,
      controller.stream,
      initialState: AuthAuthenticated(_senderUser),
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/edit',
          builder: (context, _) => BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const EditProfileScreen(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push('/edit'));
    await tester.pumpAndSettle();

    // Tap "Enregistrer" — sets _saving = true.
    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pump();

    // Now emit AuthProfileUpdated → listener should pop because _saving is true.
    controller.add(AuthProfileUpdated(_senderUser));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);

    await controller.close();
  });

  // ── Test 7 : AuthLoading hors sauvegarde (upload photo) ──────────────────

  testWidgets(
      'pendant un AuthLoading hors save (upload photo), le bouton est désactivé sans spinner',
      (tester) async {
    // A bare AuthLoading on this screen = avatar upload in progress (_saving=false).
    // The save button must NOT spin (the avatar overlay shows the spinner), but it
    // stays disabled to avoid racing the in-flight upload with a save.
    whenListen<AuthState>(
      mockAuthBloc,
      Stream.value(const AuthLoading()),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final buttons = tester.widgetList<DonyButton>(find.byType(DonyButton));
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.isLoading, isFalse); // avatar overlay owns the spinner
      expect(button.onPressed, isNull); // still disabled during the upload
    }
  });

  // ── Test 8 : tap avatar dispatche AuthAvatarUploadRequested ──────────────

  testWidgets(
    'tap sur l\'avatar dispatche AuthAvatarUploadRequested avec le path du fichier',
    (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_senderUser),
      );

      // Write a small temp file (4 bytes) so XFile.length() succeeds ≤ 10 MB.
      final tmpPath = '${Directory.systemTemp.path}/dony_test_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(tmpPath).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

      // Use the pickImageOverride seam — no platform channel required.
      final screen = EditProfileScreen(
        pickImageOverride: () async => XFile(tmpPath),
      );
      await tester.pumpWidget(_wrap(screen, mockAuthBloc));
      await tester.pumpAndSettle();

      // Ensure the avatar is on screen (top of scroll view, should already be).
      await tester.ensureVisible(find.byKey(const ValueKey('avatar_pick_gesture')));
      await tester.pump();

      // Tap then allow all async work (pick → length() → dispatch) to complete.
      await tester.tap(find.byKey(const ValueKey('avatar_pick_gesture')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      verify(
        () => mockAuthBloc.add(
          any(that: isA<AuthAvatarUploadRequested>()),
        ),
      ).called(1);
    },
  );
}
