import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/auth_method_screen.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

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
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

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
    await tester.ensureVisible(
      find.textContaining('En continuant tu acceptes nos'),
    );
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

    await tester.ensureVisible(
      find.textContaining('En continuant tu acceptes nos'),
    );
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
    expect(find.text('Connecte-toi en toute confiance'), findsOneWidget);
    expect(
      find.text(
        'Tes échanges, ton paiement et ton suivi colis sont protégés à chaque étape.',
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
      find.text('Connecte-toi en toute confiance'),
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

    await bloc.close();
  });
}
