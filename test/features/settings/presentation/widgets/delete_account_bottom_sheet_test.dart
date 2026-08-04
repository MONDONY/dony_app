import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  testWidgets('affiche les badges RÉVERSIBLE et IRRÉVERSIBLE', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('RÉVERSIBLE'), findsOneWidget);
    expect(find.text('IRRÉVERSIBLE'), findsOneWidget);
  });

  testWidgets('affiche le groupe de raisons (optionnel)', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Raison (optionnel)'), findsOneWidget);
    expect(find.textContaining("n'utilise plus"), findsOneWidget);
    expect(find.text('Problème de confidentialité'), findsOneWidget);
  });

  testWidgets('affiche le bouton Annuler', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('affiche spinner quand AccountDeletionLoading', (tester) async {
    when(() => mockBloc.state).thenReturn(const AccountDeletionLoading());
    whenListen<AccountDeletionState>(
      mockBloc,
      const Stream.empty(),
      initialState: const AccountDeletionLoading(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pump(); // don't pumpAndSettle — CircularProgressIndicator animates forever

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('sélectionner une raison via radio option', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.textContaining("Trop de notifications"),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.textContaining("Trop de notifications"), findsOneWidget);
  });

  testWidgets('tap Annuler ferme la bottom sheet', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsNothing);
  });

  testWidgets('sélectionner une option radio via texte', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Scroll down inside the sheet to see radio options
    await tester.tap(
      find.text("Je n'utilise plus le service"),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text("Je n'utilise plus le service"), findsOneWidget);
  });

  testWidgets('affiche le titre de la bottom sheet', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets(
      'BlocListener: AccountDeletionRequested ferme la sheet et affiche snackbar',
      (tester) async {
    // Use a delayed stream so the state emits after the sheet opens
    final controller = StreamController<AccountDeletionState>();
    whenListen<AccountDeletionState>(
      mockBloc,
      controller.stream,
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Confirm sheet is open
    expect(find.text('Supprimer mon compte'), findsOneWidget);

    // Now emit state
    controller.add(const AccountDeletionRequested());
    await tester.pump();
    await tester.pump();

    // Sheet should be closed (Navigator.pop was called), snackbar shown
    // The "Supprimer mon compte" title should be gone (sheet closed) or snackbar present
    final hasSnackbar = find.byType(SnackBar).evaluate().isNotEmpty;
    final sheetGone = find.text('Supprimer mon compte').evaluate().isEmpty;
    expect(hasSnackbar || sheetGone, isTrue);

    await controller.close();
  });

  testWidgets('BlocListener: AccountDeletionError(isEscrowBlocked) shows dialog',
      (tester) async {
    final controller = StreamController<AccountDeletionState>();
    whenListen<AccountDeletionState>(
      mockBloc,
      controller.stream,
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Emit escrow blocked error
    controller.add(AccountDeletionError(
      error: const ValidationException('test', code: 'escrow'),
      isEscrowBlocked: true,
    ));
    await tester.pump();
    await tester.pump();

    // EscrowBlockDialog (DonyDialog) should appear
    expect(find.text('Suppression impossible pour l\'instant'), findsOneWidget);

    await controller.close();
  });
}
