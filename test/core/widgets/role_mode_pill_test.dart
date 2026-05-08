import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/widgets/role_mode_pill.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

Widget _buildPill({required ActiveRole role, required MockActiveRoleCubit cubit}) {
  when(() => cubit.state).thenReturn(role);
  return MaterialApp(
    home: BlocProvider<ActiveRoleCubit>.value(
      value: cubit,
      child: const Scaffold(body: Stack(children: [RoleModePill()])),
    ),
  );
}

void main() {
  late MockActiveRoleCubit mockCubit;
  setUp(() => mockCubit = MockActiveRoleCubit());

  testWidgets('affiche 📦 et 🧭 en mode Expéditeur', (tester) async {
    await tester.pumpWidget(_buildPill(role: ActiveRole.sender, cubit: mockCubit));
    expect(find.text('📦'), findsOneWidget);
    expect(find.text('🧭'), findsOneWidget);
  });

  testWidgets('affiche 🧭 et 📦 en mode Voyageur', (tester) async {
    await tester.pumpWidget(_buildPill(role: ActiveRole.traveler, cubit: mockCubit));
    expect(find.text('🧭'), findsOneWidget);
    expect(find.text('📦'), findsOneWidget);
  });

  testWidgets('tap 🧭 appelle switchToTraveler quand en mode Expéditeur', (tester) async {
    await tester.pumpWidget(_buildPill(role: ActiveRole.sender, cubit: mockCubit));
    await tester.tap(find.text('🧭'));
    await tester.pump();
    verify(() => mockCubit.switchToTraveler()).called(1);
  });

  testWidgets('tap 📦 appelle switchToSender quand en mode Voyageur', (tester) async {
    await tester.pumpWidget(_buildPill(role: ActiveRole.traveler, cubit: mockCubit));
    await tester.tap(find.text('📦'));
    await tester.pump();
    verify(() => mockCubit.switchToSender()).called(1);
  });
}
