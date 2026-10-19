import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/widgets/dial_code_picker.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// [home] (par défaut [EditPhoneScreen]) dans un vrai GoRouter : « Contacter le support » pousse
/// `/support`, qui affiche ici l'origine et le message du brouillon reçu.
Widget _routerWrap(
  MockAuthBloc authBloc, {
  Widget home = const EditPhoneScreen(),
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/support',
        builder: (_, state) {
          final draft = state.extra as SupportTicketDraft?;
          return Scaffold(
            body: Column(
              children: [
                Text('support:${draft?.origin}:${draft?.category}'),
                Text(draft?.message ?? ''),
              ],
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Retrouvez le `TextSpan` portant exactement [text] dans l'arbre — même
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

    group('numéro déjà pris (YADONY-FLUTTER-PROD-Y)', () {
      late StreamController<AuthState> states;

      setUp(() {
        DonySnackbar.clearDedup();
        states = StreamController<AuthState>.broadcast();
        addTearDown(states.close);
        whenListen<AuthState>(
          mockAuthBloc,
          states.stream,
          initialState: const AuthAuthenticated(_user),
        );
      });

      Future<void> sendCodeThenFail(
        WidgetTester tester,
        AppException error,
      ) async {
        await tester.pumpWidget(_routerWrap(mockAuthBloc));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '612345678');
        await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le code'));
        await tester.pump();
        states.add(
          const AuthOtpSent(verificationId: 'vid', phoneNumber: '+33612345678'),
        );
        await tester.pumpAndSettle();
        states.add(AuthError(error));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      testWidgets(
        'phone-already-exists : bandeau explicatif + « Contacter le support »',
        (tester) async {
          await sendCodeThenFail(
            tester,
            const ConflictException('taken', code: 'phone-already-exists'),
          );

          expect(
            find.byKey(const Key('phone-conflict-banner')),
            findsOneWidget,
          );
          expect(find.text('Numéro déjà utilisé'), findsOneWidget);
          expect(
            find.text(
              'Ce numéro a déjà son propre compte Yadony. Connectez-vous avec '
              'ce numéro, ou contactez le support pour regrouper vos comptes.',
            ),
            findsOneWidget,
          );
          expect(find.text('Contacter le support'), findsOneWidget);
          // Le bandeau remplace la snackbar : pas de message en double.
          expect(find.byType(SnackBar), findsNothing);
        },
      );

      testWidgets(
        'phone-pending-deletion : bandeau « Compte en cours de suppression »',
        (tester) async {
          await sendCodeThenFail(
            tester,
            const ConflictException('pending', code: 'phone-pending-deletion'),
          );

          expect(find.text('Compte en cours de suppression'), findsOneWidget);
          expect(
            find.byKey(const Key('phone-conflict-support-cta')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        '« Contacter le support » ouvre /support avec une demande préremplie',
        (tester) async {
          await sendCodeThenFail(
            tester,
            const ConflictException('taken', code: 'phone-already-exists'),
          );

          await tester.tap(find.byKey(const Key('phone-conflict-support-cta')));
          await tester.pumpAndSettle();

          expect(
            find.text('support:phone_already_used:ACCOUNT'),
            findsOneWidget,
          );
          expect(
            find.textContaining('+33612345678'),
            findsOneWidget,
            reason: 'le numéro aide l’équipe à retrouver les deux comptes',
          );
        },
      );

      testWidgets('autre erreur : pas de bandeau, la snackbar suffit', (
        tester,
      ) async {
        await sendCodeThenFail(
          tester,
          const ValidationException('bad', code: 'phone-otp-invalid'),
        );

        expect(find.byKey(const Key('phone-conflict-banner')), findsNothing);
      });

      testWidgets('nouvel envoi de code : le bandeau disparaît', (
        tester,
      ) async {
        await tester.pumpWidget(_routerWrap(mockAuthBloc));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '612345678');
        states.add(
          const AuthError(
            ConflictException('taken', code: 'phone-already-exists'),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('phone-conflict-banner')), findsOneWidget);

        await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le code'));
        await tester.pump();

        expect(find.byKey(const Key('phone-conflict-banner')), findsNothing);
      });
    });

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

  /// Une adresse s'ajoute, jamais ne se remplace (409 `email-already-set`) :
  /// un compte qui en porte déjà une ne voit plus de champ ni d'envoi de code.
  group('EditEmailScreen — adresse déjà définie', () {
    const userWithEmail = UserModel(
      id: 'u1',
      firstName: 'Ibrahima',
      lastName: 'Diallo',
      email: 'ibrahima@exemple.com',
      roles: ['SENDER'],
      kycStatus: 'NOT_STARTED',
      status: 'ACTIVE',
    );

    testWidgets('affiche l\'adresse et l\'explication, sans champ ni envoi', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(userWithEmail),
      );

      await tester.pumpWidget(_wrap(const EditEmailScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('ibrahima@exemple.com'), findsOneWidget);
      expect(find.byKey(const Key('email-already-set-banner')), findsOneWidget);
      expect(find.text('Adresse déjà définie'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(DonyButton, 'Envoyer le code'), findsNothing);
      verifyNever(() => mockAuthBloc.add(any()));
    });

    testWidgets('« Contacter le support » ouvre une demande préremplie', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(userWithEmail),
      );

      await tester.pumpWidget(
        _routerWrap(mockAuthBloc, home: const EditEmailScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('email-already-set-support-cta')));
      await tester.pumpAndSettle();

      expect(find.text('support:email_change:ACCOUNT'), findsOneWidget);
      expect(find.textContaining('ibrahima@exemple.com'), findsOneWidget);
    });

    testWidgets('adresse vide : le formulaire d\'ajout reste proposé', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(
          UserModel(
            id: 'u1',
            firstName: 'Ibrahima',
            lastName: 'Diallo',
            email: '  ',
            roles: ['SENDER'],
            kycStatus: 'NOT_STARTED',
            status: 'ACTIVE',
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const EditEmailScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('email-already-set-banner')), findsNothing);
      expect(
        find.widgetWithText(DonyButton, 'Envoyer le code'),
        findsOneWidget,
      );
    });
  });
}
