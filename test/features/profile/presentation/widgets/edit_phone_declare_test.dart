import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/phone_verification_badge.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// Charge les vraies polices de l'app : sans elles, `flutter test` rend des
/// glyphes carrés de 1 em et toute mesure de largeur est fausse.
Future<void> _loadFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Laisse la snackbar d'erreur disparaître (persistante, 10 min, pour un
/// refus SMS) : elle couvre le bas de l'écran,
/// donc le bouton collant, tant qu'elle est affichée.
Future<void> _letSnackbarGo(WidgetTester tester) async {
  await tester.pump(const Duration(minutes: 11));
  // Un SnackBar avec action reste affiché tant qu'on ne le ferme pas.
  ScaffoldMessenger.of(
    tester.element(find.byType(Scaffold).first),
  ).clearSnackBars();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    registerFallbackValue(_FakeAuthEvent());
    await _loadFonts();
  });
  setUp(() {
    resetDeclareRouteMissing();
    // DonySnackbar déduplique sur une horloge réelle partagée entre tests.
    DonySnackbar.clearDedup();
    // Un tap manqué (hors écran, masqué) doit faire échouer le test.
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

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
    // Surface explicite, identique sur toutes les machines.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: locale ?? const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(builder: (_) => const EditPhoneScreen()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '612345678');
    await tester.ensureVisible(find.byType(DonyButton));
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
        // Message dédié : le SMS fonctionne pour ce pays, pas l'inverse.
        expect(
          find.textContaining('peut recevoir un code par SMS'),
          findsWidgets,
        );
        expect(
          find.textContaining('Connectez-vous avec votre adresse'),
          findsNothing,
        );
        await _letSnackbarGo(tester);
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
      await _letSnackbarGo(tester);
    });

    // Vraies polices, thème de l'app : le libellé doit tenir dans le bouton
    // pleine largeur du bandeau, sans coupe ni rétrécissement.
    for (final (name, locale, label) in [
      ('FR', const Locale('fr'), 'Enregistrer sans vérifier'),
      ('EN', const Locale('en'), 'Save without verifying'),
    ]) {
      testWidgets('libellé $name tient dans le bouton à 360 dp', (
        tester,
      ) async {
        if (name == 'EN') enableEnglish();
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        await open(tester, locale: locale);
        states.add(const AuthError(_blocked));
        await tester.pump();
        await tester.pump();

        final text = find.text(label);
        expect(text, findsOneWidget);
        final button = find.byKey(const Key('phone-declare-cta'));
        expect(
          tester.widget<Text>(text).style?.fontSize,
          isNull,
          reason: 'police du thème, jamais réduite',
        );
        final rendered = tester.renderObject<RenderParagraph>(text);
        final painter = TextPainter(
          text: rendered.text,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        // Police réelle chargée : un glyphe carré de 1 em ferait ~350 px.
        expect(painter.width, lessThan(260));
        expect(tester.getRect(text).width, closeTo(painter.width, 1));
        expect(
          tester.getRect(text).right,
          lessThanOrEqualTo(tester.getRect(button).right),
        );
        expect(
          tester.getRect(text).left,
          greaterThanOrEqualTo(tester.getRect(button).left),
        );
        expect(rendered.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('numéro corrigé : l offre disparaît', (tester) async {
      await open(tester);
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();
      expect(find.text('Enregistrer sans vérifier'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '699999999');
      await tester.pump();

      expect(find.text('Enregistrer sans vérifier'), findsNothing);
      await _letSnackbarGo(tester);
    });

    testWidgets('même numéro retapé à l identique : l offre reste', (
      tester,
    ) async {
      await open(tester);
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '612345678');
      await tester.pump();

      expect(find.text('Enregistrer sans vérifier'), findsOneWidget);
    });

    for (final (name, error) in <(String, AppException)>[
      ('404', const NotFoundException(apiCode: 'NOT_FOUND')),
      ('405', const NetworkException('Method Not Allowed', code: '405')),
    ]) {
      testWidgets(
        'declare $name (back sans la route) : ancien comportement, offre masquée pour la session',
        (tester) async {
          await open(tester);
          states.add(const AuthError(_blocked));
          await tester.pump();
          await tester.pump();
          await tester.tap(find.text('Enregistrer sans vérifier'));
          await tester.pump();

          states.add(AuthError(error));
          await tester.pump();
          await tester.pump();

          // Le refus SMS du serveur, tel qu'avant : son détail, sans l'offre.
          expect(find.text('Enregistrer sans vérifier'), findsNothing);
          expect(find.textContaining('Pas de SMS vers ce pays'), findsWidgets);
          await _letSnackbarGo(tester);

          // Nouveau refus country-blocked dans la même session : pas d'offre.
          await tester.ensureVisible(find.byType(DonyButton));
          await tester.tap(find.byType(DonyButton));
          await tester.pump();
          states.add(const AuthError(_blocked));
          await tester.pump();
          await tester.pump();
          expect(find.text('Enregistrer sans vérifier'), findsNothing);
          await _letSnackbarGo(tester);
        },
      );
    }

    testWidgets('panne passagère de declare : l offre reste pour réessayer', (
      tester,
    ) async {
      await open(tester);
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Enregistrer sans vérifier'));
      await tester.pump();

      states.add(
        const AuthError(
          ServiceUnavailableException('x', 'declared-phone-unavailable'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Enregistrer sans vérifier'), findsOneWidget);
      await _letSnackbarGo(tester);
    });

    testWidgets('declare 422 (numéro invalide) : l offre est retirée', (
      tester,
    ) async {
      await open(tester);
      states.add(const AuthError(_blocked));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Enregistrer sans vérifier'));
      await tester.pump();

      states.add(
        const AuthError(ValidationException('x', code: 'invalid-phone-number')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Enregistrer sans vérifier'), findsNothing);
      await _letSnackbarGo(tester);
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
