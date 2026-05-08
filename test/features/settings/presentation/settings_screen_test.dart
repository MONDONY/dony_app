import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

Widget _wrap() {
  final mockBloc = MockAccountDeletionBloc();
  when(() => mockBloc.state).thenReturn(const AccountDeletionInitial());

  return MaterialApp(
    home: BlocProvider<AccountDeletionBloc>.value(
      value: mockBloc,
      child: const SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('renders Paramètres title', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Paramètres'), findsOneWidget);
  });

  testWidgets('shows Supprimer mon compte tile', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('tapping Supprimer mon compte ouvre le bottom sheet',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    // Le bottom sheet s'ouvre avec le titre "Supprimer mon compte"
    // et les deux cartes de choix
    expect(find.text('Pause 30 jours'), findsOneWidget);
    expect(find.text('Supprimer définitivement'), findsOneWidget);
  });
}
