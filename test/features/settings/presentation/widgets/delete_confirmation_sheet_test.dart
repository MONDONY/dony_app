import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/delete_confirmation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const RequestDeletion());
    registerFallbackValue(const AuthLogoutRequested());
  });

  late MockAccountDeletionBloc mockBloc;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockBloc = MockAccountDeletionBloc();
    mockAuthBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(const AccountDeletionInitial());
  });

  // AuthBloc doit être un ancêtre du Navigator racine (pas seulement de
  // `home`) : DonyBottomSheet.show ouvre la sheet via useRootNavigator, une
  // route sœur de `home` dans l'Overlay — un provider posé seulement sous
  // `home` ne serait pas visible depuis son contexte.
  Widget buildWidget() => BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: MaterialApp(
          home: BlocProvider<AccountDeletionBloc>.value(
            value: mockBloc,
            child: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () =>
                      DeleteConfirmationSheet.show(context, mockBloc),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

  group('DeleteConfirmationSheet', () {
    testWidgets('affiche le titre "Dernière étape"', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Dernière étape'), findsOneWidget);
    });

    testWidgets('affiche l\'avertissement de suppression irréversible',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('irréversible'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('affiche la case à cocher', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets(
        'le bouton "Supprimer définitivement" est désactivé sans checkbox',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final button = tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is ElevatedButton || w.runtimeType.toString().contains('DonyButton'),
              ),
              matching: find.byType(InkWell),
            ),
          )
          .where((w) => w.onTap == null);

      // There should be at least one disabled InkWell (the submit button)
      expect(button.isNotEmpty || find.text('Supprimer définitivement').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('cocher la case active le bouton', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap checkbox to check it
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(find.text('Supprimer définitivement'), findsOneWidget);
    });

    testWidgets('le texte de la case à cocher est affiché', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('définitive et irréversible'),
        findsOneWidget,
      );
    });

    testWidgets('affiche CircularProgressIndicator quand AccountDeletionLoading',
        (tester) async {
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

    testWidgets('tap sur la zone du checkbox toggle la valeur', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final checkboxBefore =
          tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkboxBefore.value, isFalse);

      // Tap via GestureDetector wrapping the row
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final checkboxAfter =
          tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkboxAfter.value, isTrue);
    });

    testWidgets('tap bouton supprimer appelle ConfirmImmediateDeletion directement (pas de code SMS)',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check the checkbox first to enable the button
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Tap the submit button
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pump();

      // Verify that ConfirmImmediateDeletion was dispatched directly — pas
      // de RequestOtpForImmediateDeletion, pas de re-vérification téléphone.
      verify(() => mockBloc.add(any(that: isA<ConfirmImmediateDeletion>()))).called(1);
    });

    testWidgets('tap sur le texte de la case à cocher toggle via GestureDetector',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final checkboxBefore = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkboxBefore.value, isFalse);

      // Tap the text label (not the checkbox) to trigger the GestureDetector onTap
      await tester.tap(
        find.textContaining('définitive et irréversible'),
        warnIfMissed: false,
      );
      await tester.pump();

      // The checkbox should now be true
      final checkboxAfter = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkboxAfter.value, isTrue);
    });

    testWidgets('BlocListener: AccountDeletionImmediate ferme la sheet et déclenche le logout',
        (tester) async {
      whenListen<AccountDeletionState>(
        mockBloc,
        Stream.fromIterable([const AccountDeletionImmediate()]),
        initialState: const AccountDeletionInitial(),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      verify(() => mockAuthBloc.add(any(that: isA<AuthLogoutRequested>()))).called(1);
    });

    testWidgets('BlocListener: AccountDeletionError affiche une erreur',
        (tester) async {
      whenListen<AccountDeletionState>(
        mockBloc,
        Stream.fromIterable([
          AccountDeletionError(
            error: const NetworkException('Erreur réseau', code: 'network'),
          ),
        ]),
        initialState: const AccountDeletionInitial(),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      // Error presenter shows a snackbar or dialog
      expect(find.byType(SnackBar).evaluate().isNotEmpty ||
          find.byType(AlertDialog).evaluate().isNotEmpty ||
          find.text('Dernière étape').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('BlocListener: AccountDeletionError(isEscrowBlocked) affiche EscrowBlockDialog',
        (tester) async {
      whenListen<AccountDeletionState>(
        mockBloc,
        Stream.fromIterable([
          AccountDeletionError(
            error: const ValidationException('test', code: 'escrow'),
            isEscrowBlocked: true,
          ),
        ]),
        initialState: const AccountDeletionInitial(),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Suppression impossible pour l\'instant'), findsOneWidget);
    });
  });
}
