import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

GoRouter _buildRouter(AuthBloc authBloc, {bool fromProfile = false}) =>
    GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: PhoneAuthScreen(fromProfile: fromProfile),
          ),
        ),
        GoRoute(
          path: '/auth/method',
          builder: (_, _) => const Scaffold(body: Text('Method Screen')),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (_, _) => const Scaffold(body: Text('OTP Screen')),
        ),
        GoRoute(
          path: '/auth/email',
          builder: (_, _) => const Scaffold(body: Text('Email Screen')),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  AuthBloc authBloc, {
  bool fromProfile = false,
}) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _buildRouter(authBloc, fromProfile: fromProfile),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

    registerFallbackValue(const AuthSendOtpRequested(''));
    DonySnackbar.clearDedup();
  });

  tearDown(() async {
    await mockAuthBloc.close();
  });

  group('PhoneAuthScreen — affichage', () {
    testWidgets('affiche le titre Votre numéro', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.text('Votre numéro'), findsOneWidget);
    });

    testWidgets('affiche le sous-titre envoi code SMS', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.textContaining('code à 6 chiffres'), findsOneWidget);
    });

    testWidgets('affiche le bouton Recevoir le code SMS', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.text('Recevoir le code SMS'), findsOneWidget);
    });

    testWidgets('affiche le champ téléphone avec hint', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('affiche le widget PhoneAuthScreen', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.byType(PhoneAuthScreen), findsOneWidget);
    });

    testWidgets('affiche le visuel sécurité Yadony du tunnel auth', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc);

      expect(find.byType(DonyLogo), findsOneWidget);
      expect(
        find.image(
          const AssetImage('assets/illustrations/auth-login-security.png'),
        ),
        findsOneWidget,
      );
      expect(find.text('Connexion protégée'), findsOneWidget);
    });

    testWidgets('bouton Apple absent sur plateforme non-iOS', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.text('Apple'), findsNothing);
    });
  });

  group('PhoneAuthScreen — état loading', () {
    testWidgets('bouton Recevoir le code affiche un spinner pendant loading', (
      tester,
    ) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
      when(
        () => mockAuthBloc.stream,
      ).thenAnswer((_) => Stream.value(const AuthLoading()));
      await _pump(tester, mockAuthBloc);
      // DonyButton en isLoading=true affiche un CircularProgressIndicator
      // et cache le texte du label
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('PhoneAuthScreen — interaction', () {
    testWidgets('indicatif par défaut est +33 🇫🇷', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.text('+33'), findsOneWidget);
      expect(find.textContaining('🇫🇷'), findsOneWidget);
    });

    testWidgets('AuthOtpSent → naviguer vers /auth/otp', (tester) async {
      final stateStream = Stream.fromIterable([
        const AuthOtpSent(
          verificationId: 'ver-123',
          phoneNumber: '+33612345678',
        ),
      ]);
      when(() => mockAuthBloc.stream).thenAnswer((_) => stateStream);
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await _pump(tester, mockAuthBloc);
      await tester.pumpAndSettle();
      expect(find.text('OTP Screen'), findsOneWidget);
    });

    testWidgets('soumission formulaire valide dispatche AuthSendOtpRequested', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc);
      // Saisir un numéro valide dans le champ
      await tester.enterText(find.byType(TextFormField), '612345678');
      await tester.pump();
      // Taper sur le bouton "Recevoir le code"
      await tester.tap(find.text('Recevoir le code SMS'));
      await tester.pump();
      verify(
        () => mockAuthBloc.add(const AuthSendOtpRequested('+33612345678')),
      ).called(1);
    });

    testWidgets(
      'soumission formulaire vide affiche erreur "Entrez votre numéro"',
      (tester) async {
        await _pump(tester, mockAuthBloc);
        // Ne rien saisir — taper directement sur le bouton
        await tester.tap(find.text('Recevoir le code SMS'));
        await tester.pump();
        expect(find.text('Entrez votre numéro'), findsOneWidget);
      },
    );

    testWidgets('soumission numéro trop court affiche "Numéro trop court"', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc);
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.pump();
      await tester.tap(find.text('Recevoir le code SMS'));
      await tester.pump();
      expect(find.text('Numéro trop court'), findsOneWidget);
    });

    testWidgets(
      'soumission numéro commençant par 0 supprime le 0 avant dispatch',
      (tester) async {
        await _pump(tester, mockAuthBloc);
        // Numéro commençant par 0 → doit envoyer +33612345678
        await tester.enterText(find.byType(TextFormField), '0612345678');
        await tester.pump();
        await tester.tap(find.text('Recevoir le code SMS'));
        await tester.pump();
        verify(
          () => mockAuthBloc.add(const AuthSendOtpRequested('+33612345678')),
        ).called(1);
      },
    );

    testWidgets('tap sur le sélecteur d\'indicatif ouvre le bottom sheet', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc);
      // Le sélecteur est un GestureDetector autour du drapeau et code
      final flagSelector = find.text('+33');
      // La carte d'intro (AuthIntroCard) pousse le champ sous le pli du
      // viewport de test — le rendre visible avant de taper dessus.
      await tester.ensureVisible(flagSelector);
      await tester.tap(flagSelector);
      await tester.pumpAndSettle();
      // Le bottom sheet affiche "Indicatif pays"
      expect(find.text('Indicatif pays'), findsOneWidget);
    });

    // Même zone morte que sur la modification du numéro : seuls le drapeau,
    // l'indicatif et le chevron réagissaient, pas la marge de la case.
    testWidgets('toucher la marge du sélecteur d\'indicatif ouvre la liste', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc);
      await tester.ensureVisible(find.text('+33'));
      final selector = find
          .ancestor(
            of: find.text('+33'),
            matching: find.byType(GestureDetector),
          )
          .first;
      final zone = tester.getRect(selector);
      await tester.tapAt(Offset(zone.left + 3, zone.top + 3));
      await tester.pumpAndSettle();

      expect(find.text('Indicatif pays'), findsOneWidget);
    });

    testWidgets(
      'sélection d\'un indicatif dans le bottom sheet met à jour l\'affichage',
      (tester) async {
        await _pump(tester, mockAuthBloc);
        await tester.ensureVisible(find.text('+33'));
        await tester.tap(find.text('+33'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('dial_code_search')),
          'Sénégal',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sénégal (+221)'));
        await tester.pumpAndSettle();
        expect(find.text('+221'), findsOneWidget);
        expect(find.text('+33'), findsNothing);
      },
    );

    testWidgets(
      'numéro ivoirien : le zéro initial est conservé dans le format E.164',
      (tester) async {
        // Régression : le zéro sautait pour tous les pays, et le code SMS
        // partait vers +225748840874 au lieu de +2250748840874.
        await _pump(tester, mockAuthBloc);
        await tester.ensureVisible(find.text('+33'));
        await tester.tap(find.text('+33'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('dial_code_search')),
          'Ivoire',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Côte d\'Ivoire (+225)'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '0748840874');
        await tester.pump();
        await tester.tap(find.text('Recevoir le code SMS'));
        await tester.pump();
        verify(
          () => mockAuthBloc.add(const AuthSendOtpRequested('+2250748840874')),
        ).called(1);
      },
    );

    testWidgets('l\'indicatif choisi survit à une erreur d\'authentification', (
      tester,
    ) async {
      // Régression : AuthError réémettait un AuthInitial nu, l'écran
      // retombait sur la France et la soumission suivante partait en +33.
      await _pump(tester, mockAuthBloc);
      await tester.ensureVisible(find.text('+33'));
      await tester.tap(find.text('+33'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dial_code_search')),
        'Ivoire',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Côte d\'Ivoire (+225)'));
      await tester.pumpAndSettle();
      expect(find.text('+225'), findsOneWidget);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await tester.pump();
      expect(find.text('+225'), findsOneWidget);
      expect(find.text('+33'), findsNothing);
    });
  });

  group('PhoneAuthScreen — email link et OAuth new user', () {
    testWidgets('affiche le lien "Continuer avec une adresse email"', (
      tester,
    ) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
      await _pump(tester, mockAuthBloc);

      expect(find.text('Continuer avec une adresse email'), findsOneWidget);
    });

    testWidgets('tap sur le lien email navigue vers /auth/email', (
      tester,
    ) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
      await _pump(tester, mockAuthBloc);

      await tester.tap(find.text('Continuer avec une adresse email'));
      await tester.pumpAndSettle();

      expect(find.text('Email Screen'), findsOneWidget);
    });

    testWidgets(
      'AuthOAuthNewUser est ignoré par PhoneAuthScreen (géré par AuthMethodScreen)',
      (tester) async {
        whenListen(
          mockAuthBloc,
          Stream.fromIterable([
            const AuthLoading(),
            const AuthOAuthNewUser('u@google.com'),
          ]),
          initialState: const AuthInitial(),
        );
        await _pump(tester, mockAuthBloc);
        await tester.pumpAndSettle();

        // PhoneAuthScreen ne gère plus AuthOAuthNewUser — reste sur le même écran
        expect(find.byType(PhoneAuthScreen), findsOneWidget);
      },
    );
  });

  testWidgets('affiche l\'écran en anglais', (tester) async {
    useEnglish();
    await _pump(tester, mockAuthBloc);

    expect(find.text('Get SMS code'), findsOneWidget);
    expect(find.text('Your number'), findsOneWidget);
    expect(find.text('Continue with an email address'), findsOneWidget);
  });

  group('PhoneAuthScreen — envoi SMS refusé (sms-otp-disabled)', () {
    const countryDetail =
        "Les codes SMS n'arrivent pas en ce moment en Côte d'Ivoire. "
        'Connecte-toi avec ton adresse e-mail, Google ou Apple.';
    const blocked = AuthError(
      ServiceUnavailableException(countryDetail, 'sms-otp-disabled'),
    );

    testWidgets('bandeau persistant avec le detail du back, sans snackbar', (
      tester,
    ) async {
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([const AuthLoading(), blocked]),
        initialState: const AuthInitial(),
      );
      await _pump(tester, mockAuthBloc);
      await tester.pump();

      final banner = find.byKey(const Key('sms-otp-disabled-banner'));
      expect(banner, findsOneWidget);
      expect(
        find.descendant(of: banner, matching: find.text('SMS indisponible')),
        findsOneWidget,
      );
      // Une seule occurrence : le bandeau, pas de snackbar en double.
      expect(find.text(countryDetail), findsOneWidget);
      expect(find.text('Voir les options'), findsOneWidget);
    });

    testWidgets('le lien mène à l\'écran des moyens de connexion', (
      tester,
    ) async {
      when(() => mockAuthBloc.state).thenReturn(blocked);
      await _pump(tester, mockAuthBloc);

      final link = find.byKey(const Key('sms-otp-disabled-other-methods'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.text('Method Screen'), findsOneWidget);
    });

    testWidgets('detail vide → texte de repli dans le bandeau', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(
        const AuthError(ServiceUnavailableException('', 'sms-otp-disabled')),
      );
      await _pump(tester, mockAuthBloc);

      expect(
        find.text(
          "La connexion par SMS n'est pas disponible pour ce numéro. "
          'Connectez-vous avec votre adresse e-mail, Google ou Apple.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('depuis le profil : bandeau sans lien (déjà connecté)', (
      tester,
    ) async {
      when(() => mockAuthBloc.state).thenReturn(blocked);
      await _pump(tester, mockAuthBloc, fromProfile: true);

      expect(find.byKey(const Key('sms-otp-disabled-banner')), findsOneWidget);
      expect(
        find.byKey(const Key('sms-otp-disabled-other-methods')),
        findsNothing,
      );
    });

    testWidgets('autre erreur : snackbar habituelle, pas de bandeau', (
      tester,
    ) async {
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([
          const AuthLoading(),
          const AuthError(
            ValidationException('x', code: 'invalid-phone-number'),
          ),
        ]),
        initialState: const AuthInitial(),
      );
      await _pump(tester, mockAuthBloc);
      await tester.pump();

      expect(find.byKey(const Key('sms-otp-disabled-banner')), findsNothing);
      expect(find.text('Numéro injoignable'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    for (final english in [false, true]) {
      testWidgets('lien sur une ligne, sans débordement, à 360 dp '
          '(${english ? 'EN' : 'FR'})', (tester) async {
        if (english) useEnglish();
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        when(() => mockAuthBloc.state).thenReturn(blocked);
        await _pump(tester, mockAuthBloc);

        final label = english ? 'See options' : 'Voir les options';
        expect(tester.takeException(), isNull);
        // Police de test Ahem (1 em par glyphe, plus large que la vraie) :
        // si le libellé tient ici, il tient dans l'app.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(paragraph.size.width),
        );
        expect(
          paragraph.size.height,
          lessThan(2 * paragraph.text.style!.fontSize!),
        );
      });
    }
  });
}
