import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/widgets/dial_code_picker.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';
import '../../../../helpers/l10n_test_helpers.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

const _user = UserModel(
  id: 'u1',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  roles: ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

Widget _wrap(Widget child, MockAuthBloc authBloc) {
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp(home: child),
  );
}

/// Retrouve le `TextSpan` portant exactement [text] dans l'arbre — même
/// helper que `reception_confirm_screen_test.dart` pour vérifier la mise en
/// forme produite par `emphasizedSpans`.
TextSpan? _findSpan(WidgetTester tester, String text) {
  TextSpan? found;
  void visit(InlineSpan span) {
    if (found != null) return;
    if (span is TextSpan) {
      if (span.text == text) {
        found = span;
        return;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child);
      }
    }
  }

  for (final element in find.byType(Text).evaluate()) {
    final textSpan = (element.widget as Text).textSpan;
    if (textSpan != null) visit(textSpan);
  }
  return found;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
  });

  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
  });

  tearDown(() {
    mockAuthBloc.close();
  });

  group('EditEmailScreen', () {
    testWidgets(
      'affiche le titre et le champ email, bouton "Envoyer le code"',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: const AuthAuthenticated(_user),
        );

        await tester.pumpWidget(_wrap(const EditEmailScreen(), mockAuthBloc));
        await tester.pumpAndSettle();

        expect(find.text("Modifier l'email"), findsOneWidget);
        expect(
          find.widgetWithText(DonyButton, 'Envoyer le code'),
          findsOneWidget,
        );
      },
    );

    testWidgets('saisie + envoi dispatche AuthEmailOtpSendRequested', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(_user),
      );

      await tester.pumpWidget(_wrap(const EditEmailScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nouvel@email.com');
      await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le code'));
      await tester.pump();

      verify(
        () => mockAuthBloc.add(any(that: isA<AuthEmailOtpSendRequested>())),
      ).called(1);
    });

    testWidgets(
      'après AuthEmailOtpSent, passe à l\'étape code + bouton "Vérifier"',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          Stream.value(const AuthEmailOtpSent('nouvel@email.com')),
          initialState: const AuthAuthenticated(_user),
        );

        await tester.pumpWidget(_wrap(const EditEmailScreen(), mockAuthBloc));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(DonyButton, 'Vérifier'), findsOneWidget);
      },
    );

    // ── FLUTTER-BX : seule la vérification lancée ici ferme l'écran ──────────
    Future<List<Object?>> pumpPushed(
      WidgetTester tester,
      StreamController<AuthState> controller,
    ) async {
      final results = <Object?>[];
      whenListen<AuthState>(
        mockAuthBloc,
        controller.stream,
        initialState: const AuthAuthenticated(_user),
      );
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(builder: (_) => const EditEmailScreen()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
          mockAuthBloc,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets(
      'AuthProfileUpdated de fond (synchro) : l\'écran reste ouvert',
      (tester) async {
        final controller = StreamController<AuthState>();
        final results = await pumpPushed(tester, controller);

        controller.add(const AuthProfileUpdated(_user));
        await tester.pumpAndSettle();

        expect(find.byType(EditEmailScreen), findsOneWidget);
        expect(results, isEmpty);
        await controller.close();
      },
    );

    testWidgets(
      'code vérifié puis AuthProfileUpdated : ferme l\'écran avec true',
      (tester) async {
        final controller = StreamController<AuthState>();
        final results = await pumpPushed(tester, controller);

        await tester.enterText(find.byType(TextField), 'nouvel@email.com');
        await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le code'));
        await tester.pump();
        controller.add(const AuthEmailOtpSent('nouvel@email.com'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(Pinput), '123456');
        await tester.pump();
        verify(
          () => mockAuthBloc.add(
            any(that: isA<AuthAddEmailFromProfileRequested>()),
          ),
        ).called(1);

        controller.add(
          AuthProfileUpdated(_user.copyWith(email: 'nouvel@email.com')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EditEmailScreen), findsNothing);
        expect(results, [true]);
        await controller.close();
      },
    );

    testWidgets(
      'étape code : « Code envoyé à » met l\'email en gras (emphasizedSpans)',
      (tester) async {
        final controller = StreamController<AuthState>();
        whenListen<AuthState>(
          mockAuthBloc,
          controller.stream,
          initialState: const AuthAuthenticated(_user),
        );

        await tester.pumpWidget(_wrap(const EditEmailScreen(), mockAuthBloc));
        await tester.pumpAndSettle();

        // Saisie + envoi : `_pendingEmail` (utilisé par le message) n'est
        // renseigné que par `_sendOtp()`, jamais par le seul état du bloc.
        await tester.enterText(find.byType(TextField), 'nouvel@email.com');
        await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le code'));
        await tester.pump();
        controller.add(const AuthEmailOtpSent('nouvel@email.com'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Code envoyé à nouvel@email.com',
            findRichText: true,
          ),
          findsOneWidget,
        );
        final span = _findSpan(tester, 'nouvel@email.com');
        expect(span, isNotNull, reason: 'le span du contact doit exister');
        expect(span!.style?.fontWeight, FontWeight.w700);

        await controller.close();
      },
    );

    testWidgets('titre et bouton en anglais', (tester) async {
      useEnglish();
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(_user),
      );

      await tester.pumpWidget(_wrap(const EditEmailScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Edit email'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Send code'), findsOneWidget);
    });
  });

  group('EditPhoneScreen', () {
    testWidgets(
      'affiche le titre et le champ numéro, bouton "Envoyer le code"',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: const AuthAuthenticated(_user),
        );

        await tester.pumpWidget(_wrap(const EditPhoneScreen(), mockAuthBloc));
        await tester.pumpAndSettle();

        expect(find.text('Modifier le numéro'), findsOneWidget);
        expect(
          find.widgetWithText(DonyButton, 'Envoyer le code'),
          findsOneWidget,
        );
      },
    );

    testWidgets('saisie + envoi dispatche AuthSendOtpRequested', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(_user),
      );

      await tester.pumpWidget(_wrap(const EditPhoneScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '612345678');
      await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le code'));
      await tester.pump();

      verify(
        () => mockAuthBloc.add(any(that: isA<AuthSendOtpRequested>())),
      ).called(1);
    });

    testWidgets(
      'après AuthOtpSent, passe à l\'étape code + bouton "Vérifier"',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          Stream.value(
            const AuthOtpSent(
              verificationId: 'vid',
              phoneNumber: '+33612345678',
            ),
          ),
          initialState: const AuthAuthenticated(_user),
        );

        await tester.pumpWidget(_wrap(const EditPhoneScreen(), mockAuthBloc));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(DonyButton, 'Vérifier'), findsOneWidget);
      },
    );

    // Rage clicks PostHog du 27/09 (x≈90, y≈182) : le sélecteur ne réagissait
    // que sur les pixels du drapeau, de l'indicatif et du chevron. Un toucher
    // dans sa marge, pourtant dans la case dessinée, ne faisait rien.
    testWidgets('toucher la marge du sélecteur d\'indicatif ouvre la liste', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(_user),
      );

      await tester.pumpWidget(_wrap(const EditPhoneScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      final dialCode = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('+') ?? false),
      );
      final selector = find
          .ancestor(of: dialCode, matching: find.byType(GestureDetector))
          .first;
      final zone = tester.getRect(selector);
      await tester.tapAt(Offset(zone.left + 3, zone.top + 3));
      await tester.pumpAndSettle();

      expect(find.byType(DialCodePicker), findsOneWidget);
    });

    // Le code se remplit d'un toucher sur la suggestion du clavier : la
    // vérification part sans passer par le bouton.
    testWidgets(
      'étape code : six chiffres saisis déclenchent la vérification',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          Stream.value(
            const AuthOtpSent(
              verificationId: 'vid',
              phoneNumber: '+33612345678',
            ),
          ),
          initialState: const AuthAuthenticated(_user),
        );

        await tester.pumpWidget(_wrap(const EditPhoneScreen(), mockAuthBloc));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(Pinput), '482913');
        await tester.pump();

        verify(
          () => mockAuthBloc.add(
            any(that: isA<AuthAddPhoneFromProfileRequested>()),
          ),
        ).called(1);
      },
    );

    testWidgets('titre et bouton en anglais', (tester) async {
      useEnglish();
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(_user),
      );

      await tester.pumpWidget(_wrap(const EditPhoneScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Edit phone number'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Send code'), findsOneWidget);
    });
  });
}
