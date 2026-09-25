import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
