import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockLocalAuthBloc extends MockBloc<LocalAuthEvent, LocalAuthState>
    implements LocalAuthBloc {}

GoRouter _buildRouter(
  AuthBloc authBloc,
  LocalAuthBloc localAuthBloc, {
  bool verifyMode = false,
}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<LocalAuthBloc>.value(value: localAuthBloc),
        ],
        child: LocalAuthScreen(verifyMode: verifyMode),
      ),
    ),
    GoRoute(
      path: '/auth/method',
      builder: (_, __) => const Scaffold(body: Text('Méthode de connexion')),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  AuthBloc authBloc,
  LocalAuthBloc localAuthBloc, {
  bool verifyMode = false,
}) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _buildRouter(
        authBloc,
        localAuthBloc,
        verifyMode: verifyMode,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockLocalAuthBloc mockLocalAuthBloc;

  setUpAll(() {
    registerFallbackValue(const AuthSwitchAccountRequested());
    registerFallbackValue(const LocalAuthStarted());
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockLocalAuthBloc = MockLocalAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
    // L'écran déverrouillage affiche le clavier PIN quand un PIN est requis.
    when(
      () => mockLocalAuthBloc.state,
    ).thenReturn(const LocalAuthPinRequired());
    when(
      () => mockLocalAuthBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() async {
    await mockAuthBloc.close();
    await mockLocalAuthBloc.close();
  });

  group('LocalAuthScreen — bouton "Autre compte"', () {
    testWidgets('affiche le bouton en mode déverrouillage (verifyMode=false)', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc, mockLocalAuthBloc);
      expect(find.text('Autre compte'), findsOneWidget);
    });

    testWidgets('MASQUE le bouton en mode vérification (verifyMode=true)', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc, mockLocalAuthBloc, verifyMode: true);
      expect(find.text('Autre compte'), findsNothing);
    });

    testWidgets('tap puis "Continuer" → dispatch AuthSwitchAccountRequested', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc, mockLocalAuthBloc);

      await tester.tap(find.text('Autre compte'));
      await tester.pumpAndSettle();

      // Le dialogue de confirmation apparaît.
      expect(find.text('Changer de compte ?'), findsOneWidget);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      verify(
        () => mockAuthBloc.add(const AuthSwitchAccountRequested()),
      ).called(1);
      // Navigation vers l'écran de choix du mode de connexion.
      expect(find.text('Méthode de connexion'), findsOneWidget);
    });

    testWidgets('tap puis "Annuler" → aucun dispatch, dialogue fermé', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc, mockLocalAuthBloc);

      await tester.tap(find.text('Autre compte'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Changer de compte ?'), findsNothing);
      verifyNever(() => mockAuthBloc.add(const AuthSwitchAccountRequested()));
    });
  });
}
