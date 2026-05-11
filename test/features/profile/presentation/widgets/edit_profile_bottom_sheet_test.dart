import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

// ── Fixture ────────────────────────────────────────────────────────────────────

final _user = UserModel(
  id: 'user-test',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  email: 'ibra@test.com',
  city: 'Paris',
  birthDate: DateTime(1990, 6, 15),
  roles: const ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

// ── Test harness ───────────────────────────────────────────────────────────────

Widget _wrap(MockAuthBloc authBloc) {
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => EditProfileBottomSheet.show(ctx),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

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

  // ── Test 1 : affiche le formulaire avec les 4 champs ──────────────────────

  testWidgets('affiche le formulaire avec les 4 champs', (tester) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthInitial(),
    );

    await tester.pumpWidget(_wrap(mockAuthBloc));
    await _openSheet(tester);

    expect(find.text('Prénom'), findsWidgets);
    expect(find.text('Nom de famille'), findsWidgets);
    expect(find.text('Email (optionnel)'), findsWidgets);
    expect(find.text('Date de naissance'), findsWidgets);
    expect(find.text("Ville / lieu d'habitation"), findsWidgets);
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  // ── Test 2 : pré-remplit les champs depuis AuthAuthenticated ──────────────

  testWidgets('pré-remplit les champs depuis AuthAuthenticated', (tester) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_user),
    );

    await tester.pumpWidget(_wrap(mockAuthBloc));
    await _openSheet(tester);

    // Check that TextFormField controllers contain pre-filled values
    // via the EditableText nodes in the widget tree
    final editableTexts = tester.widgetList<EditableText>(
      find.byType(EditableText),
    ).map((e) => e.controller.text).toList();

    expect(editableTexts, contains('Ibrahima'));
    expect(editableTexts, contains('Diallo'));
    expect(editableTexts, contains('ibra@test.com'));
    expect(editableTexts, contains('Paris'));

    // Birth date should be formatted as dd/MM/yyyy
    expect(find.text('15/06/1990'), findsOneWidget);
  });

  // ── Test 3 : dispatche AuthUpdateProfileRequested au tap sur Enregistrer ──

  testWidgets('dispatche AuthUpdateProfileRequested au tap sur Enregistrer',
      (tester) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthInitial(),
    );

    await tester.pumpWidget(_wrap(mockAuthBloc));
    await _openSheet(tester);

    // Enter text in the first TextFormField (Prénom)
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'Moussa');
    await tester.pump();

    // Scroll to the Enregistrer button (it may be off-screen)
    await tester.scrollUntilVisible(
      find.text('Enregistrer'),
      150,
      scrollable: find.byType(Scrollable).last,
    );

    // Tap the save button
    await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
    await tester.pump();

    verify(() => mockAuthBloc.add(any(that: isA<AuthUpdateProfileRequested>())))
        .called(1);
  });

  // ── Test 4 : désactive le bouton pendant AuthLoading ─────────────────────

  testWidgets('désactive le bouton pendant AuthLoading', (tester) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: const AuthLoading(),
    );

    await tester.pumpWidget(_wrap(mockAuthBloc));

    // Tap to open the sheet — don't use pumpAndSettle because the loading
    // spinner has an infinite animation that will cause a timeout.
    await tester.tap(find.text('Ouvrir'));
    // Let the bottom sheet appear and the initial frame render
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final filledButton = tester.widget<FilledButton>(
      find.byType(FilledButton).first,
    );
    expect(filledButton.onPressed, isNull);
  });

  // ── Test 5 : affiche snackbar erreur sur AuthError ────────────────────────

  testWidgets('affiche snackbar erreur sur AuthError', (tester) async {
    // Start with AuthInitial, then emit AuthError after the sheet is open
    final stateController = StreamController<AuthState>();
    whenListen<AuthState>(
      mockAuthBloc,
      stateController.stream,
      initialState: AuthInitial(),
    );

    await tester.pumpWidget(_wrap(mockAuthBloc));
    await _openSheet(tester);

    // Emit the error state
    stateController.add(AuthError(NetworkException('Connexion impossible')));
    await tester.pump(); // let the listener fire
    await tester.pump(const Duration(milliseconds: 100)); // let SnackBar render

    // ErrorPresenter resolves NetworkException via ErrorCatalog → _networkGeneric.
    expect(find.text('Erreur réseau'), findsOneWidget);

    await stateController.close();
  });
}
