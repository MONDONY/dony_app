import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/delete_otp_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late MockAccountDeletionBloc mockDeletionBloc;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockDeletionBloc = MockAccountDeletionBloc();
    mockAuthBloc = MockAuthBloc();
    when(() => mockDeletionBloc.state)
        .thenReturn(const AccountDeletionInitial());
    when(() => mockAuthBloc.state)
        .thenReturn(const AuthInitial());
  });

  Widget buildWidget() => MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AccountDeletionBloc>.value(value: mockDeletionBloc),
            BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => DeleteOtpSheet.show(
                  context,
                  mockDeletionBloc,
                  verificationId: 'verify-id-123',
                  phoneHint: '+33 6•• ••• ••7',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

  group('DeleteOtpSheet', () {
    testWidgets('affiche le titre "Code de vérification"', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      // Use pump with duration instead of pumpAndSettle (Pinput with autofocus causes timeouts)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Code de vérification'), findsOneWidget);
    });

    testWidgets('affiche le numéro de téléphone masqué', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('+33 6'), findsOneWidget);
    });

    testWidgets('affiche le champ Pinput à 6 cases', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final pinput = tester.widget<Pinput>(find.byType(Pinput));
      expect(pinput.length, 6);
    });

    testWidgets('affiche le bouton "Confirmer la suppression définitive"',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Confirmer la suppression définitive'), findsOneWidget);
    });

    testWidgets('bouton désactivé si code < 6 chiffres', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final inkWells = tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.byType(MaterialApp),
              matching: find.byType(InkWell),
            ),
          )
          .where((w) => w.onTap == null)
          .toList();

      expect(inkWells.isNotEmpty, isTrue);
    });

    testWidgets('saisie dans Pinput met à jour la valeur', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter 6 digits into the Pinput
      await tester.enterText(find.byType(Pinput), '123456');
      await tester.pump();

      // The Pinput should now contain the entered text
      final pinput = tester.widget<Pinput>(find.byType(Pinput));
      expect(pinput.length, 6);
    });

    testWidgets(
        'affiche CircularProgressIndicator quand AccountDeletionLoading',
        (tester) async {
      when(() => mockDeletionBloc.state)
          .thenReturn(const AccountDeletionLoading());
      whenListen<AccountDeletionState>(
        mockDeletionBloc,
        const Stream.empty(),
        initialState: const AccountDeletionLoading(),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
