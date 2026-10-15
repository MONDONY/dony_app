import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/google_auth_flag.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/auth_method_screen.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/stripe_account_test_doubles.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// Cet écran ne dispatche pas encore `AuthNewAccountAuthenticated` dans ces
// tests, mais `_continueAfterNewAccount` lit `StripeAccountBloc` et
// `BusinessPrefsBloc` (fournis à l'échelle de l'app dans `app.dart`) dès que
// cet état arrive : les provisionner ici évite qu'un futur test qui l'émet
// casse sans raison apparente (`ProviderNotFoundException`).
class _MockBusinessPrefsBloc
    extends MockBloc<BusinessPrefsEvent, BusinessPrefsState>
    implements BusinessPrefsBloc {}

_MockBusinessPrefsBloc _stubBusinessPrefsBloc() {
  final bloc = _MockBusinessPrefsBloc();
  when(() => bloc.state).thenReturn(const BusinessPrefsState());
  when(() => bloc.stream).thenAnswer((_) => Stream.value(bloc.state));
  return bloc;
}

Widget _app(AuthBloc bloc) => MaterialApp.router(
  theme: AppTheme.light(),
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: bloc),
            BlocProvider<StripeAccountBloc>.value(
              value: stubStripeAccountBloc(),
            ),
            BlocProvider<BusinessPrefsBloc>.value(
              value: _stubBusinessPrefsBloc(),
            ),
          ],
          child: const AuthMethodScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Recherche avec carte')),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const Scaffold(body: Text('Page CGU')),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const Scaffold(body: Text('Page confidentialité')),
      ),
    ],
  ),
);

void main() {
  setUp(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
  tearDown(() {
    setSmsAuthEnabled(kSmsAuthEnabledDefault);
    debugEnvironmentOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  // Guideline Apple 1.2 : l'utilisateur accepte explicitement les CGU, qui
  // excluent tout contenu choquant ou comportement abusif, avant de créer
  // un compte ou de se connecter. Une mention passive ne suffisait pas.
  group('acceptation des CGU', () {
    late MockAuthBloc bloc;

    setUp(() {
      bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() => bloc.close());

    testWidgets('affiche la clause de tolérance zéro', (tester) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.textContaining(
          "Aucun contenu choquant ni comportement abusif n'est toléré",
        ),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('sans la case, Google ne part pas et la case est signalée', (
      tester,
    ) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Continuer avec Google'));
      await tester.pump();

      verifyNever(() => bloc.add(const AuthGoogleSignInRequested()));
      expect(
        find.text(
          'Cochez la case pour accepter les conditions avant de continuer.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).isError, isTrue);
    });

    testWidgets('sans la case, le bouton e-mail ne navigue pas', (
      tester,
    ) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.ensureVisible(find.text('Continuer avec mon email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer avec mon email'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthMethodScreen), findsOneWidget);
      expect(
        find.text(
          'Cochez la case pour accepter les conditions avant de continuer.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('case cochée : Google part et l\'erreur disparaît', (
      tester,
    ) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Continuer avec Google'));
      await tester.pump();
      await acceptTerms(tester);

      expect(
        find.text(
          'Cochez la case pour accepter les conditions avant de continuer.',
        ),
        findsNothing,
      );
      await tester.tap(find.text('Continuer avec Google'));
      await tester.pump();

      verify(() => bloc.add(const AuthGoogleSignInRequested())).called(1);
    });

    testWidgets('toucher le libellé coche puis décoche la case', (
      tester,
    ) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      final label = find.textContaining('comportement abusif');
      await tester.tap(label);
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.tap(label);
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('le mode invité reste libre sans la case', (tester) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.ensureVisible(find.text('Parcourir sans compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parcourir sans compte'));
      await tester.pump();

      verify(() => bloc.add(const AuthGuestSessionRequested())).called(1);
    });
  });

  // La mention légale était bleue et soulignée mais ne portait aucun
  // `recognizer` : rien n'écoutait le toucher. On demandait d'accepter des
  // documents qu'aucun geste ne permettait d'ouvrir, sur l'écran même que les
  // relecteurs Apple et Google visitent avant de créer un compte.
  testWidgets('toucher « CGU » ouvre la page des conditions', (tester) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // La mention vit sous la ligne de flottaison de la fenêtre de test.
    await tester.ensureVisible(find.textContaining("J'accepte les"));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tapOnText(find.textRange.ofSubstring('CGU'));
    await tester.pumpAndSettle();

    expect(find.text('Page CGU'), findsOneWidget);
  });

  testWidgets('toucher « politique de confidentialité » ouvre la page dédiée', (
    tester,
  ) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.ensureVisible(find.textContaining("J'accepte les"));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tapOnText(
      find.textRange.ofSubstring('politique de confidentialité'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Page confidentialité'), findsOneWidget);
  });

  testWidgets('affiche le logo Yadony et les messages rassurants', (
    tester,
  ) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(DonyLogo), findsOneWidget);
    expect(find.text('Sécurisé'), findsOneWidget);
    expect(find.text('Connectez-vous en toute confiance'), findsOneWidget);
    expect(
      find.text(
        'Vos échanges, votre paiement et votre suivi colis sont protégés à chaque étape.',
      ),
      findsOneWidget,
    );
    expect(find.text('Parcourir sans compte'), findsOneWidget);
    expect(
      find.text(
        'Accès limité : recherche uniquement. Connexion requise pour publier, contacter, réserver ou payer.',
      ),
      findsOneWidget,
    );
    expect(find.byType(DonyHeroAvatar), findsNothing);
    expect(find.text('🦋'), findsNothing);

    await bloc.close();
  });

  testWidgets('respecte le theme clair Yadony blanc et bleu', (tester) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    final theme = AppTheme.light();

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, theme.scaffoldBackgroundColor);

    final title = tester.widget<Text>(
      find.text('Connectez-vous en toute confiance'),
    );
    expect(title.style?.color, theme.colorScheme.onSurface);

    final badge = tester.widget<Text>(find.text('Sécurisé'));
    expect(badge.style?.color, theme.colorScheme.primary);

    await bloc.close();
  });

  testWidgets(
    'masque le bouton téléphone tant que le SMS OTP backend n\'est pas confirmé',
    (tester) async {
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Continuer avec mon téléphone'), findsNothing);
      expect(find.text('Continuer avec Google'), findsOneWidget);
      expect(find.text('Continuer avec mon email'), findsOneWidget);
      expect(find.text('Parcourir sans compte'), findsOneWidget);

      await bloc.close();
    },
  );

  // Google Play re-signe les builds Android avec sa clé App Signing, dont le
  // client OAuth appartient au projet Firebase prod : en staging le bouton
  // Google ouvrait un écran qui se refermait aussitôt (DEVELOPER_ERROR).
  testWidgets('masque le bouton Google sur Android en staging', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    debugEnvironmentOverride = 'staging';
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Continuer avec Google'), findsNothing);
    expect(find.text('Continuer avec mon email'), findsOneWidget);
    expect(find.text('Parcourir sans compte'), findsOneWidget);

    await bloc.close();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('garde le bouton Google sur iOS en staging', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    debugEnvironmentOverride = 'staging';
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Continuer avec Apple'), findsOneWidget);

    await bloc.close();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'affiche le bouton téléphone une fois le SMS OTP confirmé par le backend',
    (tester) async {
      setSmsAuthEnabled(true);
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Continuer avec mon téléphone'), findsOneWidget);

      await bloc.close();
    },
  );

  testWidgets(
    'Parcourir sans compte declenche AuthGuestSessionRequested sans naviguer',
    (tester) async {
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      // Titre au vouvoiement plus long (FLUTTER-CD) : le lien peut passer
      // sous le pli à 800×600.
      await tester.ensureVisible(find.text('Parcourir sans compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parcourir sans compte'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const AuthGuestSessionRequested())).called(1);
      // Pas de navigation optimiste : on attend la confirmation du succès.
      expect(find.text('Recherche avec carte'), findsNothing);

      await bloc.close();
    },
  );

  testWidgets(
    'session invitee ouverte avec succes ouvre la vraie recherche avec carte',
    (tester) async {
      final bloc = MockAuthBloc();
      whenListen(
        bloc,
        Stream.fromIterable(<AuthState>[
          const AuthLoading(),
          const AuthGuestSessionReady(),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Recherche avec carte'), findsOneWidget);

      await bloc.close();
    },
  );

  testWidgets('echec de la session invitee affiche une erreur sans naviguer', (
    tester,
  ) async {
    final bloc = MockAuthBloc();
    whenListen(
      bloc,
      Stream.fromIterable(<AuthState>[
        const AuthLoading(),
        const AuthError(
          NetworkException(
            'Impossible de démarrer la navigation sans compte. '
            'Vérifiez votre connexion.',
            code: 'guest-session-failed',
          ),
        ),
      ]),
      initialState: const AuthInitial(),
    );

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Recherche avec carte'), findsNothing);
    expect(
      find.text(
        'Impossible de démarrer la navigation sans compte. '
        'Vérifiez votre connexion.',
      ),
      findsOneWidget,
    );

    await bloc.close();
  });

  testWidgets('affiche les boutons de connexion en anglais', (tester) async {
    useEnglish();
    setSmsAuthEnabled(true);
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Browse without an account'), findsOneWidget);
    expect(find.textContaining('I accept the'), findsOneWidget);
  });

  // Rage clicks PostHog du 27/09 : pendant la connexion Google, Apple ou
  // invitée, les boutons restaient actifs et sans retour visuel, et les
  // testeurs iOS tapaient à répétition.
  group('pendant une connexion lancée depuis cet écran', () {
    late MockAuthBloc bloc;
    late StreamController<AuthState> states;

    setUp(() {
      bloc = MockAuthBloc();
      states = StreamController<AuthState>.broadcast();
      var current = const AuthInitial() as AuthState;
      when(() => bloc.state).thenAnswer((_) => current);
      when(() => bloc.stream).thenAnswer((_) => states.stream);
      states.stream.listen((s) => current = s);
    });

    tearDown(() async {
      await states.close();
      await bloc.close();
    });

    Future<void> emit(WidgetTester tester, AuthState state) async {
      states.add(state);
      await tester.pump();
      await tester.pump();
    }

    bool googleEnabled(WidgetTester tester) => tester
        .widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Continuer avec Google'),
            matching: find.byType(OutlinedButton),
          ),
        )
        .enabled;

    bool emailEnabled(WidgetTester tester) => tester
        .widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Continuer avec mon email'),
            matching: find.byType(OutlinedButton),
          ),
        )
        .enabled;

    testWidgets('Google affiche un spinner et bloque les autres boutons', (
      tester,
    ) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await acceptTerms(tester);
      await tester.tap(find.text('Continuer avec Google'));
      await emit(tester, const AuthLoading());

      verify(() => bloc.add(const AuthGoogleSignInRequested())).called(1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(emailEnabled(tester), isFalse);

      // Un second toucher pendant l'attente ne relance rien.
      await tester.tap(find.text('Continuer avec Google'));
      await tester.pump();
      verifyNever(() => bloc.add(const AuthGoogleSignInRequested()));
    });

    testWidgets('une annulation Google rend la main aux boutons', (
      tester,
    ) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await acceptTerms(tester);
      await tester.tap(find.text('Continuer avec Google'));
      await emit(tester, const AuthLoading());
      await emit(tester, const AuthInitial());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(googleEnabled(tester), isTrue);
      expect(emailEnabled(tester), isTrue);
    });

    testWidgets('une erreur rend la main aux boutons', (tester) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      // Titre au vouvoiement plus long (FLUTTER-CD) : le lien peut passer
      // sous le pli à 800×600.
      await tester.ensureVisible(find.text('Parcourir sans compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parcourir sans compte'));
      await emit(tester, const AuthLoading());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(googleEnabled(tester), isFalse);

      await emit(
        tester,
        const AuthError(NetworkException('Hors ligne', code: 'offline')),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(googleEnabled(tester), isTrue);
    });

    // L'AuthBloc est global : un chargement qui ne vient pas de cet écran ne
    // doit pas en figer les boutons.
    testWidgets('un chargement non lancé ici ne bloque rien', (tester) async {
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await emit(tester, const AuthLoading());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(googleEnabled(tester), isTrue);
      expect(emailEnabled(tester), isTrue);
    });

    testWidgets('Apple affiche son spinner sur iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_app(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await acceptTerms(tester);
      await tester.tap(find.text('Continuer avec Apple'));
      await emit(tester, const AuthLoading());

      verify(() => bloc.add(const AuthAppleSignInRequested())).called(1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(googleEnabled(tester), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
