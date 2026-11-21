import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/phone_verification_badge.dart';
import 'package:dony/core/error/app_exception.dart';
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

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _user = UserModel(
  id: 'u1',
  roles: ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

const _declared = UserModel(
  id: 'u1',
  roles: ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
  declaredPhone: '+33612345678',
  declaredPhoneLevel: 'DECLARED',
);

const _blocked = ServiceUnavailableException(
  'Pas de SMS vers ce pays',
  'sms-otp-disabled',
  {'reason': 'country-blocked', 'callingCode': '33'},
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeAuthEvent()));

  late _MockAuthBloc bloc;
  late StreamController<AuthState> states;

  setUp(() {
    bloc = _MockAuthBloc();
    states = StreamController<AuthState>.broadcast();
    whenListen<AuthState>(
      bloc,
      states.stream,
      initialState: const AuthAuthenticated(_user),
    );
  });

  tearDown(() async {
    await states.close();
    await bloc.close();
  });

  /// Ouvre l'écran par un push (pour observer le `pop(true)` du succès).
  Future<List<Object?>> open(WidgetTester tester, {Locale? locale}) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(builder: (_) => const EditPhoneScreen()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
          locale: locale ?? const Locale('fr'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '612345678');
    await tester.tap(find.byType(DonyButton));
    await tester.pump();
    return results;
  }

  group('pays sans SMS (country-blocked)', () {
    testWidgets(
      'propose « Enregistrer sans vérifier » et n envoie pas de code',
      (tester) async {
        await open(tester);
        expect(find.text('Enregistrer sans vérifier'), findsNothing);

        states.add(const AuthError(_blocked));
        await tester.pump();
        await tester.pump();

        expect(find.text('Enregistrer sans vérifier'), findsOneWidget);
        // Un seul envoi de code (celui qui a échoué), aucun autre.
        verify(
          () => bloc.add(any(that: isA<AuthSendOtpRequested>())),
        ).called(1);
        verifyNever(
          () => bloc.add(any(that: isA<AuthAddPhoneFromProfileRequested>())),
        );
      },
    );

    testWidgets('toucher l offre déclare le numéro, sans nouvel envoi SMS', (
      tester,
    ) async {
      await open(tester);
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Enregistrer sans vérifier'));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured.last, const AuthPhoneDeclared('+33612345678'));
      expect(captured.whereType<AuthSendOtpRequested>(), hasLength(1));
    });

    testWidgets('succès : retour au profil (pop true) avec confirmation', (
      tester,
    ) async {
      final results = await open(tester);
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Enregistrer sans vérifier'));
      await tester.pump();

      states.add(const AuthProfileUpdated(_declared));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(find.byType(EditPhoneScreen), findsNothing);
    });

    testWidgets(
      '409 phone-declare-not-allowed : erreur SMS normale, offre retirée',
      (tester) async {
        await open(tester);
        states.add(const AuthError(_blocked));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.text('Enregistrer sans vérifier'));
        await tester.pump();

        states.add(
          const AuthError(
            ConflictException('x', code: 'phone-declare-not-allowed'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Enregistrer sans vérifier'), findsNothing);
        expect(find.byType(EditPhoneScreen), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    testWidgets('une autre erreur d envoi ne propose pas l offre', (
      tester,
    ) async {
      await open(tester);
      states.add(
        const AuthError(
          ServiceUnavailableException(
            'Service indisponible',
            'sms-otp-disabled',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Enregistrer sans vérifier'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('libellé FR sur une ligne à 360 dp, sans exception', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await open(tester);
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();

      final label = find.text('Enregistrer sans vérifier');
      expect(label, findsOneWidget);
      final text = tester.widget<Text>(label);
      expect(text.maxLines, 1);
      expect(text.style?.fontSize, isNull);
      // Une seule ligne : hauteur du texte inférieure à deux lignes.
      expect(tester.getSize(label).height, lessThan(30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('libellé EN sur une ligne à 360 dp, sans exception', (
      tester,
    ) async {
      enableEnglish();
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await open(tester, locale: const Locale('en'));
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();

      final label = find.text('Save without verifying');
      expect(label, findsOneWidget);
      expect(tester.getSize(label).height, lessThan(30));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'un numéro déclaré s affiche avec son badge dans le badge widget',
    (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: PhoneVerificationBadge(_declared.declaredPhoneVerification!),
          ),
        ),
      );
      expect(find.text('Non vérifié'), findsOneWidget);
    },
  );
}
