import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/widgets/role_mode_pill.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

UserModel _userWith({bool isTraveler = false}) => UserModel(
      id: 'user-1',
      kycStatus: 'NOT_STARTED',
      status: 'ACTIVE',
      roles: isTraveler ? const ['SENDER', 'TRAVELER'] : const ['SENDER'],
    );

Widget _buildPill({
  required ActiveRole role,
  required MockActiveRoleCubit cubit,
  required MockAuthBloc authBloc,
}) {
  when(() => cubit.state).thenReturn(role);
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<ActiveRoleCubit>.value(value: cubit),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: const Scaffold(body: Stack(children: [RoleModePill()])),
    ),
  );
}

void main() {
  late MockActiveRoleCubit mockCubit;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockCubit = MockActiveRoleCubit();
    mockAuthBloc = MockAuthBloc();
  });

  group('RoleModePill — utilisateur non voyageur', () {
    setUp(() {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(isTraveler: false)),
      );
    });

    testWidgets('affiche rien (SizedBox.shrink) quand isTraveler = false',
        (tester) async {
      await tester.pumpWidget(
          _buildPill(role: ActiveRole.sender, cubit: mockCubit, authBloc: mockAuthBloc));
      expect(find.text('📦'), findsNothing);
      expect(find.text('🧭'), findsNothing);
    });
  });

  group('RoleModePill — utilisateur voyageur', () {
    setUp(() {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_userWith(isTraveler: true)),
      );
    });

    testWidgets('affiche 📦 et 🧭 en mode Expéditeur', (tester) async {
      await tester.pumpWidget(
          _buildPill(role: ActiveRole.sender, cubit: mockCubit, authBloc: mockAuthBloc));
      expect(find.text('📦'), findsOneWidget);
      expect(find.text('🧭'), findsOneWidget);
    });

    testWidgets('affiche 🧭 et 📦 en mode Voyageur', (tester) async {
      await tester.pumpWidget(
          _buildPill(role: ActiveRole.traveler, cubit: mockCubit, authBloc: mockAuthBloc));
      expect(find.text('🧭'), findsOneWidget);
      expect(find.text('📦'), findsOneWidget);
    });

    testWidgets('tap 🧭 appelle switchToTraveler quand en mode Expéditeur',
        (tester) async {
      await tester.pumpWidget(
          _buildPill(role: ActiveRole.sender, cubit: mockCubit, authBloc: mockAuthBloc));
      await tester.tap(find.text('🧭'));
      await tester.pump();
      verify(() => mockCubit.switchToTraveler()).called(1);
    });

    testWidgets('tap 📦 appelle switchToSender quand en mode Voyageur',
        (tester) async {
      await tester.pumpWidget(
          _buildPill(role: ActiveRole.traveler, cubit: mockCubit, authBloc: mockAuthBloc));
      await tester.tap(find.text('📦'));
      await tester.pump();
      verify(() => mockCubit.switchToSender()).called(1);
    });
  });
}
