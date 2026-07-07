import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/presentation/screens/recipient_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class FakeRecipientEvent extends Fake implements RecipientEvent {}

// NB: fullName/phone deliberately differ from the DonyTextField hints
// ('Mamadou Diallo' / '+22177123456') to avoid false-positive text matches
// on hint text rendered by an unfilled field.
const _existing = Recipient(
  id: 'r-1',
  fullName: 'Aissatou Ba',
  phoneE164: '+221781112233',
  city: 'Dakar',
  country: 'SN',
  isDefault: true,
);

Widget _wrap(
  RecipientBloc bloc, {
  String? recipientId,
  String? initialFullName,
  String? initialPhoneE164,
}) => BlocProvider<RecipientBloc>.value(
  value: bloc,
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => RecipientEditScreen(
            recipientId: recipientId,
            initialFullName: initialFullName,
            initialPhoneE164: initialPhoneE164,
          ),
        ),
      ],
    ),
  ),
);

/// Same as [_wrap] but seeds the navigation stack with a parent route so
/// that `context.pop()` inside [RecipientEditScreen] has somewhere to go.
Widget _wrapEditing(RecipientBloc bloc, {required String recipientId}) =>
    BlocProvider<RecipientBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/edit',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Recipients')),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, __) =>
                      RecipientEditScreen(recipientId: recipientId),
                ),
              ],
            ),
          ],
        ),
      ),
    );

/// Create-mode wrapper: a parent route with a button that
/// `await context.push<bool>(...)` into [RecipientEditScreen] with no
/// `recipientId` — mirrors the picker sheet's real `_createNew` flow, which
/// needs the pushed `true` to know it should reload/select the new entry.
/// [onPopped] receives the value the edit screen popped with.
Widget _wrapCreate(RecipientBloc bloc, {ValueChanged<bool?>? onPopped}) =>
    BlocProvider<RecipientBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/parent',
          routes: [
            GoRoute(
              path: '/parent',
              builder: (context, __) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      final result = await context.push<bool>('/parent/new');
                      onPopped?.call(result);
                    },
                    child: const Text('Parent'),
                  ),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, __) => const RecipientEditScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    );

void main() {
  late MockRecipientBloc bloc;

  setUpAll(() => registerFallbackValue(FakeRecipientEvent()));

  setUp(() {
    bloc = MockRecipientBloc();
  });

  testWidgets(
    'prefills name and phone from constructor args for a new recipient',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const RecipientState(status: RecipientStatus.success));
      await tester.pumpWidget(
        _wrap(
          bloc,
          initialFullName: 'Awa Diakité',
          initialPhoneE164: '+221771234567',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Awa Diakité'), findsOneWidget);
      expect(find.text('+221771234567'), findsOneWidget);
    },
  );

  testWidgets(
    'prefills from existing recipient when editing and renders default toggle ON',
    (tester) async {
      // The prefill runs inside BlocConsumer.listener, which only fires on a
      // *new* stream emission (not on the widget's initial state) — mirror
      // that with whenListen so the success state carrying the recipient is
      // actually delivered through the stream, like in the app when the list
      // bloc emits its loaded state.
      whenListen<RecipientState>(
        bloc,
        Stream.value(
          const RecipientState(
            status: RecipientStatus.success,
            recipients: [_existing],
          ),
        ),
        initialState: const RecipientState(status: RecipientStatus.loading),
      );
      await tester.pumpWidget(_wrapEditing(bloc, recipientId: 'r-1'));
      // The insta-pop-on-load bug is fixed (`_submitted` now gates the pop
      // branch, not `_initialized`) — pumpAndSettle() is safe here, the
      // screen stays put after the prefill load.
      await tester.pumpAndSettle();

      expect(find.text('Aissatou Ba'), findsOneWidget);
      expect(find.text('+221781112233'), findsOneWidget);

      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
    },
  );

  testWidgets(
    'edit mode does NOT pop on the initial prefill load (no submit yet)',
    (tester) async {
      whenListen<RecipientState>(
        bloc,
        Stream.value(
          const RecipientState(
            status: RecipientStatus.success,
            recipients: [_existing],
          ),
        ),
        initialState: const RecipientState(status: RecipientStatus.loading),
      );
      await tester.pumpWidget(_wrapEditing(bloc, recipientId: 'r-1'));
      await tester.pumpAndSettle();

      // The form is still on screen (not popped back to the parent route)
      // even though a success state was already emitted for the prefill.
      expect(find.text('Modifier le destinataire'), findsOneWidget);
      expect(find.text('Recipients'), findsNothing);
    },
  );

  testWidgets(
    'create mode pops true after a real post-submit success (fix 1)',
    (tester) async {
      // Nested route stack so `context.pop(true)` has a parent to land on
      // and we can assert we're back there (mirrors the picker's real
      // `_createNew` flow, which awaits `context.push<bool>(...)`).
      final states = StreamController<RecipientState>();
      addTearDown(states.close);
      whenListen<RecipientState>(
        bloc,
        states.stream,
        // Mirrors the router-created bloc in the real create flow:
        // `getIt<RecipientBloc>()..add(RecipientLoaded)` — an initial load
        // success arrives before any submit. With the fix this must NOT
        // pop (only a real submit should).
        initialState: const RecipientState(status: RecipientStatus.success),
      );
      bool? popped;
      await tester.pumpWidget(_wrapCreate(bloc, onPopped: (v) => popped = v));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent'));
      await tester.pumpAndSettle();

      // Still on the create screen after the initial load success.
      expect(find.text('Nouveau destinataire'), findsOneWidget);
      expect(find.text('Parent'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom complet').first,
        'Fatou Sow',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone (E.164)').first,
        '+221771234567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ville').first,
        'Dakar',
      );
      await tester.pump();

      await tester.tap(find.text('Enregistrer'));
      await tester.pump();

      // Drive the post-submit loading -> success emission.
      states.add(const RecipientState(status: RecipientStatus.loading));
      await tester.pump();
      states.add(const RecipientState(status: RecipientStatus.success));
      await tester.pumpAndSettle();

      // Popped back with `true` to the parent route.
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Nouveau destinataire'), findsNothing);
      expect(popped, isTrue);
    },
  );

  testWidgets(
    'dispatches RecipientCreated with isDefault true when toggle is switched on',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const RecipientState(status: RecipientStatus.success));
      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom complet').first,
        'Fatou Sow',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone (E.164)').first,
        '+221771234567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ville').first,
        'Dakar',
      );
      await tester.pump();

      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      await tester.tap(find.text('Enregistrer'));
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<RecipientCreated>())),
      ).captured.cast<RecipientCreated>();
      expect(captured, hasLength(1));
      expect(captured.single.isDefault, isTrue);
    },
  );

  testWidgets(
    'dispatches RecipientCreated with isDefault false when toggle untouched',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const RecipientState(status: RecipientStatus.success));
      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom complet').first,
        'Fatou Sow',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone (E.164)').first,
        '+221771234567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ville').first,
        'Dakar',
      );
      await tester.pump();

      await tester.tap(find.text('Enregistrer'));
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<RecipientCreated>())),
      ).captured.cast<RecipientCreated>();
      expect(captured, hasLength(1));
      expect(captured.single.isDefault, isFalse);
    },
  );
}
