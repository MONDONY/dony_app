import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAccountDeletionBloc extends Mock implements AccountDeletionBloc {}

void main() {
  late AccountDeletionBloc bloc;

  setUp(() {
    bloc = _MockAccountDeletionBloc();
    when(() => bloc.state).thenReturn(const AccountDeletionInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche les boutons de suppression et annulation', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountDeletionBloc>.value(
        value: bloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => DeleteAccountBottomSheet.show(ctx),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer définitivement'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
  });
}
