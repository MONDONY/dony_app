import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_logo.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

GoRouter _buildRouter(AuthBloc authBloc) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const PhoneAuthScreen(),
      ),
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

Future<void> _pump(WidgetTester tester, AuthBloc authBloc) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _buildRouter(authBloc),
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
  });

  tearDown(() async {
    await mockAuthBloc.close();
  });

  group('PhoneAuthScreen — affichage', () {
    testWidgets('affiche le titre Ton numéro', (tester) async {
      await _pump(tester, mockAuthBloc);
      expect(find.text('Ton numéro'), findsOneWidget);
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

    testWidgets(
      'sélection d\'un indicatif dans le bottom sheet dispatche AuthDialCodeChanged',
      (tester) async {
        registerFallbackValue(
          const AuthDialCodeChanged(code: '+221', flag: '🇸🇳'),
        );
        await _pump(tester, mockAuthBloc);
        // Ouvrir le bottom sheet
        await tester.ensureVisible(find.text('+33'));
        await tester.tap(find.text('+33'));
        await tester.pumpAndSettle();
        // Appuyer sur Sénégal
        await tester.tap(find.textContaining('Sénégal'));
        await tester.pump();
        verify(
          () => mockAuthBloc.add(
            const AuthDialCodeChanged(code: '+221', flag: '🇸🇳'),
          ),
        ).called(1);
      },
    );
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
}
