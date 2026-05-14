import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/data/firebase_phone_reauth.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionRepository extends Mock
    implements AccountDeletionRepository {}

class MockFirebasePhoneReauth extends Mock implements FirebasePhoneReauth {}

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

void main() {
  late MockAccountDeletionBloc mockBloc;

  setUp(() {
    mockBloc = MockAccountDeletionBloc();
    when(() => mockBloc.state).thenReturn(const AccountDeletionInitial());
  });

  Widget buildWidget() => MaterialApp(
        home: BlocProvider<AccountDeletionBloc>.value(
          value: mockBloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => DeleteAccountBottomSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('bouton Continuer grisé si aucune carte sélectionnée',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Le bouton de validation (variant primary/destructive) utilise InkWell.
    // Avec mode == null, onTap est null → le bouton est désactivé.
    final inkWells = tester
        .widgetList<InkWell>(
          find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
        )
        .toList();
    expect(
      inkWells.where((w) => w.onTap == null).isNotEmpty,
      isTrue,
    );
  });

  testWidgets('sélectionner carte hard → label Continuer →',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(find.text('Continuer →'), findsOneWidget);
  });

  testWidgets('sélectionner carte soft → label Confirmer la pause',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pause 30 jours'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmer la pause'), findsOneWidget);
  });
}
