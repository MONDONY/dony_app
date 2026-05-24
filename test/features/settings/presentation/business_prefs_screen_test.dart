import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/screens/business_prefs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessPrefsBloc extends MockBloc<BusinessPrefsEvent, BusinessPrefsState>
    implements BusinessPrefsBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// Helper to create UserModel with specific roles
UserModel _makeUser({List<String> roles = const ['SENDER']}) => UserModel(
      id: 'test-user-id',
      roles: roles,
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

void main() {
  late MockBusinessPrefsBloc mockPrefsBloc;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockPrefsBloc = MockBusinessPrefsBloc();
    mockAuthBloc = MockAuthBloc();
    when(() => mockPrefsBloc.state).thenReturn(const BusinessPrefsState());
  });

  Widget buildScreen() => MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BusinessPrefsBloc>.value(value: mockPrefsBloc),
            BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          ],
          child: const BusinessPrefsScreen(),
        ),
      );

  testWidgets('section MES TRAJETS masquée si rôle SENDER uniquement', (tester) async {
    when(() => mockAuthBloc.state)
        .thenReturn(AuthAuthenticated(_makeUser(roles: const ['SENDER'])));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsNothing);
    expect(find.text('Poids par défaut'), findsNothing);
  });

  testWidgets('section MES TRAJETS visible si rôle TRAVELER présent', (tester) async {
    when(() => mockAuthBloc.state)
        .thenReturn(AuthAuthenticated(_makeUser(roles: const ['SENDER', 'TRAVELER'])));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsOneWidget);
    expect(find.text('Poids par défaut'), findsOneWidget);
    expect(find.text('Prix minimum'), findsOneWidget);
    expect(find.text('Mode de contact'), findsOneWidget);
    expect(find.text('Délai de réponse'), findsOneWidget);
  });

  testWidgets('section MES TRAJETS visible si rôle TRAVELER-only', (tester) async {
    when(() => mockAuthBloc.state)
        .thenReturn(AuthAuthenticated(_makeUser(roles: const ['TRAVELER'])));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsOneWidget);
  });

  testWidgets('section MES TRAJETS masquée si non authentifié', (tester) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsNothing);
  });

  testWidgets('banner erreur affiché si errorMessage non null', (tester) async {
    when(() => mockPrefsBloc.state).thenReturn(
        const BusinessPrefsState(errorMessage: 'Impossible de synchroniser. Réessayez.'));
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Impossible de synchroniser. Réessayez.'), findsOneWidget);
  });
}
