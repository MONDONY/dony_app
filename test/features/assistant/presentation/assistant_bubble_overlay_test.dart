import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/app/main_shell.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/data/assistant_repository.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_blockers.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_bubble_overlay.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockAssistantBloc extends MockBloc<AssistantEvent, AssistantState>
    implements AssistantBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPrefsBloc extends MockBloc<AppPreferencesEvent, AppPreferencesState>
    implements AppPreferencesBloc {}

class _FakeAppPreferencesEvent extends Fake implements AppPreferencesEvent {}

class _MockAssistantRepository extends Mock implements AssistantRepository {}

class _MockSupportRepository extends Mock implements SupportRepository {}

const _bubbleKey = ValueKey('assistant-bubble');
const _homeButtonKey = ValueKey('home-button');
const _sheetButtonKey = ValueKey('sheet-button');
const _dialogButtonKey = ValueKey('dialog-button');

int _homeBuilds = 0;
int _homeTaps = 0;
String? _assistantSource;

final _user = UserModel.fromJson(const {
  'id': 'u1',
  'roles': ['SENDER'],
  'kycStatus': 'VERIFIED',
});

final _otherUser = UserModel.fromJson(const {
  'id': 'u2',
  'roles': ['SENDER'],
  'kycStatus': 'VERIFIED',
});

void main() {
  late _MockAssistantBloc assistantBloc;
  late _MockAuthBloc authBloc;
  late _MockPrefsBloc prefsBloc;
  late GoRouter router;
  late AssistantBubbleBlockers blockers;

  setUpAll(() {
    registerFallbackValue(_FakeAppPreferencesEvent());
    registerFallbackValue(const AssistantResetRequested());
    registerFallbackValue(<AssistantHistoryTurn>[]);
  });

  setUp(() {
    _homeBuilds = 0;
    _homeTaps = 0;
    _assistantSource = null;
    blockers = AssistantBubbleBlockers();
    assistantBloc = _MockAssistantBloc();
    authBloc = _MockAuthBloc();
    prefsBloc = _MockPrefsBloc();
    when(
      () => assistantBloc.state,
    ).thenReturn(const AssistantState(available: true));
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_user));
    when(() => prefsBloc.state).thenReturn(
      const AppPreferencesState(preferences: UserPreferencesModel()),
    );
    if (getIt.isRegistered<AssistantBloc>()) getIt.unregister<AssistantBloc>();
    getIt.registerSingleton<AssistantBloc>(assistantBloc);
    addTearDown(() {
      if (getIt.isRegistered<AssistantBloc>()) {
        getIt.unregister<AssistantBloc>();
      }
    });
  });

  Future<void> pump(
    WidgetTester tester, {
    String initialLocation = '/home',
    EdgeInsets? viewInsets,
    FakeViewPadding padding = FakeViewPadding.zero,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    if (viewInsets != null) {
      tester.view.viewInsets = FakeViewPadding(bottom: viewInsets.bottom);
    }
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: initialLocation,
      observers: [AssistantModalObserver(blockers)],
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) {
            _homeBuilds++;
            return Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      key: _homeButtonKey,
                      onPressed: () => _homeTaps++,
                      child: const Text('home'),
                    ),
                    Builder(
                      builder: (context) => TextButton(
                        key: _sheetButtonKey,
                        onPressed: () => unawaited(
                          showModalBottomSheet<void>(
                            context: context,
                            useRootNavigator: true,
                            builder: (_) => const SizedBox(
                              height: 200,
                              child: Text('sheet'),
                            ),
                          ),
                        ),
                        child: const Text('open-sheet'),
                      ),
                    ),
                    Builder(
                      builder: (context) => TextButton(
                        key: _dialogButtonKey,
                        onPressed: () => unawaited(
                          showDialog<void>(
                            context: context,
                            builder: (_) =>
                                const AlertDialog(content: Text('dialog')),
                          ),
                        ),
                        child: const Text('open-dialog'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/assistant',
          builder: (_, state) {
            _assistantSource = state.uri.queryParameters['source'];
            return const Scaffold(body: Text('assistant'));
          },
        ),
        GoRoute(
          path: '/camera',
          builder: (_, _) => HideAssistantBubble(
            blockers: blockers,
            child: const Scaffold(body: Text('camera')),
          ),
        ),
        GoRoute(
          path: '/auth/phone',
          builder: (_, _) => const Scaffold(body: Text('auth')),
        ),
        GoRoute(
          path: '/settings/security/change-pin',
          builder: (_, _) => const Scaffold(body: Text('pin')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<AppPreferencesBloc>.value(value: prefsBloc),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: child!),
                    AssistantBubbleOverlay(router: router, blockers: blockers),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Transitions de cycle de vie dans l'ordre exigé par Flutter.
  void backgroundThenResume(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Finder bubble() => find.byKey(_bubbleKey);

  group('visibilité', () {
    testWidgets('affichée sur un écran de l’app connectée', (tester) async {
      await pump(tester);
      expect(bubble(), findsOneWidget);
    });

    testWidgets('absente pour un invité', (tester) async {
      when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
      await pump(tester);
      expect(bubble(), findsNothing);
    });

    testWidgets('absente quand l’utilisateur l’a masquée', (tester) async {
      when(() => prefsBloc.state).thenReturn(
        const AppPreferencesState(
          preferences: UserPreferencesModel(assistantBubbleEnabled: false),
        ),
      );
      await pump(tester);
      expect(bubble(), findsNothing);
    });

    testWidgets('absente quand l’assistant est éteint (404 ou 403)', (
      tester,
    ) async {
      when(
        () => assistantBloc.state,
      ).thenReturn(const AssistantState(disabled: true));
      await pump(tester);
      expect(bubble(), findsNothing);
    });

    testWidgets('absente clavier ouvert', (tester) async {
      await pump(tester, viewInsets: const EdgeInsets.only(bottom: 300));
      expect(bubble(), findsNothing);
    });

    testWidgets('absente sur l’authentification et le code PIN', (
      tester,
    ) async {
      await pump(tester, initialLocation: '/auth/phone');
      expect(bubble(), findsNothing);
      router.go('/settings/security/change-pin');
      await tester.pumpAndSettle();
      expect(bubble(), findsNothing);
    });

    testWidgets('suit la navigation : cachée sur /assistant, de retour après', (
      tester,
    ) async {
      await pump(tester);
      expect(bubble(), findsOneWidget);
      unawaited(router.push('/assistant'));
      await tester.pumpAndSettle();
      expect(find.text('assistant'), findsOneWidget);
      expect(bubble(), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(bubble(), findsOneWidget);
      router.go('/auth/phone');
      await tester.pumpAndSettle();
      expect(bubble(), findsNothing);
      router.go('/home');
      await tester.pumpAndSettle();
      expect(bubble(), findsOneWidget);
    });

    testWidgets('pages poussées les unes sur les autres : le dessus décide', (
      tester,
    ) async {
      await pump(tester);
      unawaited(router.push('/settings/security/change-pin'));
      await tester.pumpAndSettle();
      expect(bubble(), findsNothing);
      unawaited(router.push('/assistant'));
      await tester.pumpAndSettle();
      expect(bubble(), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('pin'), findsOneWidget);
      expect(bubble(), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(bubble(), findsOneWidget);
    });

    testWidgets('apparaît dès que l’assistant redevient joignable ou que le '
        'compte se connecte', (tester) async {
      final auth = StreamController<AuthState>.broadcast();
      addTearDown(() => unawaited(auth.close()));
      whenListen(
        authBloc,
        auth.stream,
        initialState: const AuthGuestSessionReady(),
      );
      await pump(tester);
      expect(bubble(), findsNothing);
      auth.add(AuthAuthenticated(_user));
      await tester.pumpAndSettle();
      expect(bubble(), findsOneWidget);
    });
  });

  group('ouverture et position', () {
    testWidgets('toucher ouvre /assistant?source=bubble', (tester) async {
      await pump(tester);
      await tester.tap(bubble());
      await tester.pumpAndSettle();
      expect(find.text('assistant'), findsOneWidget);
      expect(_assistantSource, 'bubble');
      expect(visibleRoutePath(router), '/assistant');
      // L’écran envoie lui-même AssistantOpened : l’envoyer ici doublerait
      // l’événement `assistant_opened`.
      verifyNever(() => assistantBloc.add(any(that: isA<AssistantOpened>())));
    });

    testWidgets('le premier toucher consomme l’aide', (tester) async {
      await pump(tester);
      expect(find.textContaining('Une question sur l'), findsOneWidget);
      await tester.tap(bubble());
      await tester.pumpAndSettle();
      verify(() => prefsBloc.add(const AssistantHintDismissed())).called(1);
    });

    testWidgets('aide déjà vue : ni aide ni nouvel événement au toucher', (
      tester,
    ) async {
      when(() => prefsBloc.state).thenReturn(
        const AppPreferencesState(
          preferences: UserPreferencesModel(assistantHintSeen: true),
        ),
      );
      await pump(tester);
      expect(find.textContaining('Une question sur l'), findsNothing);
      await tester.tap(bubble());
      await tester.pumpAndSettle();
      verifyNever(() => prefsBloc.add(any()));
    });

    testWidgets('toucher l’aide la ferme sans ouvrir l’assistant', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.textContaining('Une question sur l'));
      await tester.pumpAndSettle();
      verify(() => prefsBloc.add(const AssistantHintDismissed())).called(1);
      expect(find.text('assistant'), findsNothing);
    });

    testWidgets('glisser enregistre côté et hauteur au lâcher seulement', (
      tester,
    ) async {
      when(() => prefsBloc.state).thenReturn(
        const AppPreferencesState(
          preferences: UserPreferencesModel(assistantHintSeen: true),
        ),
      );
      await pump(tester);
      final gesture = await tester.startGesture(tester.getCenter(bubble()));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(-40, 5));
        await tester.pump(const Duration(milliseconds: 16));
      }
      verifyNever(() => prefsBloc.add(any()));
      await gesture.up();
      await tester.pumpAndSettle();
      final captured = verify(() => prefsBloc.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final moved = captured.single as AssistantBubbleMoved;
      expect(moved.side, 'left');
      expect(moved.y, inInclusiveRange(0.0, 1.0));
      expect(find.text('assistant'), findsNothing);
    });

    testWidgets('la bulle laisse libre la barre d’onglets et la safe area', (
      tester,
    ) async {
      when(() => prefsBloc.state).thenReturn(
        const AppPreferencesState(
          preferences: UserPreferencesModel(
            assistantBubbleY: 1,
            assistantHintSeen: true,
          ),
        ),
      );
      await pump(tester, padding: const FakeViewPadding(top: 47, bottom: 34));
      final rect = tester.getRect(bubble());
      expect(
        rect.bottom,
        lessThanOrEqualTo(844 - 34 - MainShell.navBarContentHeight),
      );
      expect(rect.right, closeTo(390 - 12, 0.5));
    });

    testWidgets('côté gauche lu dans les préférences', (tester) async {
      when(() => prefsBloc.state).thenReturn(
        const AppPreferencesState(
          preferences: UserPreferencesModel(assistantBubbleSide: 'left'),
        ),
      );
      await pump(tester);
      expect(tester.getRect(bubble()).left, closeTo(12, 0.5));
    });
  });

  group('disponibilité (sonde)', () {
    testWidgets('absente tant que la sonde n’a pas répondu vrai', (
      tester,
    ) async {
      when(() => assistantBloc.state).thenReturn(const AssistantState());
      await pump(tester);
      expect(bubble(), findsNothing);
    });

    testWidgets('la sonde part à l’entrée en session connectée', (
      tester,
    ) async {
      await pump(tester);
      verify(
        () => assistantBloc.add(const AssistantStatusRequested()),
      ).called(1);
    });

    testWidgets('pas de sonde pour un invité', (tester) async {
      when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
      await pump(tester);
      verifyNever(
        () => assistantBloc.add(any(that: isA<AssistantStatusRequested>())),
      );
    });

    testWidgets('la connexion déclenche la sonde, une seule fois', (
      tester,
    ) async {
      final auth = StreamController<AuthState>.broadcast();
      addTearDown(() => unawaited(auth.close()));
      whenListen(
        authBloc,
        auth.stream,
        initialState: const AuthGuestSessionReady(),
      );
      await pump(tester);
      auth.add(AuthAuthenticated(_user));
      await tester.pumpAndSettle();
      auth.add(AuthProfileUpdated(_user));
      await tester.pumpAndSettle();
      verify(
        () => assistantBloc.add(const AssistantStatusRequested()),
      ).called(1);
    });

    testWidgets('retour au premier plan : sonde non forcée', (tester) async {
      await pump(tester);
      clearInteractions(assistantBloc);
      backgroundThenResume(tester);
      await tester.pump();
      verify(
        () => assistantBloc.add(const AssistantStatusRequested(force: false)),
      ).called(1);
    });

    testWidgets('retour au premier plan sans session : pas de sonde', (
      tester,
    ) async {
      when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
      await pump(tester);
      backgroundThenResume(tester);
      await tester.pump();
      verifyNever(
        () => assistantBloc.add(any(that: isA<AssistantStatusRequested>())),
      );
    });
  });

  group('session', () {
    testWidgets('chargement ou erreur d’une session ouverte : la bulle reste', (
      tester,
    ) async {
      final auth = StreamController<AuthState>.broadcast();
      addTearDown(() => unawaited(auth.close()));
      whenListen(authBloc, auth.stream, initialState: AuthAuthenticated(_user));
      await pump(tester);
      expect(bubble(), findsOneWidget);
      auth.add(const AuthLoading());
      await tester.pumpAndSettle();
      expect(bubble(), findsOneWidget);
      auth.add(const AuthError(NetworkException('boum')));
      await tester.pumpAndSettle();
      expect(bubble(), findsOneWidget);
    });

    testWidgets('verrou PIN, compte supprimé ou invité : la bulle part', (
      tester,
    ) async {
      final auth = StreamController<AuthState>.broadcast();
      addTearDown(() => unawaited(auth.close()));
      whenListen(authBloc, auth.stream, initialState: AuthAuthenticated(_user));
      await pump(tester);
      for (final state in <AuthState>[
        const AuthLocked(),
        const AuthAccountDeleted(),
        const AuthGuestSessionReady(),
      ]) {
        auth.add(AuthAuthenticated(_user));
        await tester.pumpAndSettle();
        expect(bubble(), findsOneWidget);
        auth.add(state);
        await tester.pumpAndSettle();
        expect(bubble(), findsNothing, reason: '$state');
      }
    });

    testWidgets('chargement sans session : pas de bulle', (tester) async {
      when(() => authBloc.state).thenReturn(const AuthLoading());
      await pump(tester);
      expect(bubble(), findsNothing);
    });
  });

  group('feuilles, dialogues et écrans à caméra', () {
    testWidgets('feuille ouverte : bulle masquée, fermée : de retour', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(_sheetButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);
      expect(bubble(), findsNothing);
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(bubble(), findsOneWidget);
    });

    testWidgets('dialogue ouvert : bulle masquée, fermé : de retour', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(_dialogButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);
      expect(bubble(), findsNothing);
      await tester.tapAt(const Offset(10, 600));
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsNothing);
      expect(bubble(), findsOneWidget);
    });

    testWidgets('écran qui se déclare plein écran : bulle masquée', (
      tester,
    ) async {
      await pump(tester);
      unawaited(router.push('/camera'));
      await tester.pumpAndSettle();
      expect(find.text('camera'), findsOneWidget);
      expect(bubble(), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(bubble(), findsOneWidget);
    });
  });

  group('bulle d’aide', () {
    testWidgets('fermée (et écrite) quand on change de route', (tester) async {
      await pump(tester);
      expect(find.textContaining('Une question sur l'), findsOneWidget);
      router.go('/settings/security/change-pin');
      await tester.pumpAndSettle();
      router.go('/home');
      await tester.pumpAndSettle();
      verify(() => prefsBloc.add(const AssistantHintDismissed())).called(1);
      expect(find.textContaining('Une question sur l'), findsNothing);
      expect(bubble(), findsOneWidget);
    });

    testWidgets('masquée sans écriture tant qu’on reste sur l’écran', (
      tester,
    ) async {
      await pump(tester);
      await tester.pump(const Duration(seconds: 1));
      verifyNever(() => prefsBloc.add(any()));
    });
  });

  group('couche transparente', () {
    testWidgets('les touchers hors de la bulle atteignent l’écran dessous', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(_homeButtonKey));
      expect(_homeTaps, 1);
    });

    testWidgets('masquée, la couche ne bloque rien non plus', (tester) async {
      when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
      await pump(tester);
      await tester.tap(find.byKey(_homeButtonKey));
      expect(_homeTaps, 1);
    });

    testWidgets('un glissement ne reconstruit pas l’écran dessous', (
      tester,
    ) async {
      when(() => prefsBloc.state).thenReturn(
        const AppPreferencesState(
          preferences: UserPreferencesModel(assistantHintSeen: true),
        ),
      );
      await pump(tester);
      final before = _homeBuilds;
      final gesture = await tester.startGesture(tester.getCenter(bubble()));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(-10, -5));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_homeBuilds, before);
    });
  });

  group('changement de compte (vrai BLoC)', () {
    late AssistantBloc real;
    late _MockAssistantRepository repository;
    late StreamController<AuthState> auth;
    late AnalyticsService analytics;

    setUp(() async {
      repository = _MockAssistantRepository();
      when(() => repository.status()).thenAnswer((_) async => true);
      when(
        () => repository.ask(
          question: any(named: 'question'),
          locale: any(named: 'locale'),
          history: any(named: 'history'),
        ),
      ).thenAnswer(
        (_) async => const AssistantAnswer(
          answer: 'Réponse pour A',
          answered: true,
          actions: [],
          provider: 'groq',
          remainingToday: 3,
        ),
      );
      analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      await analytics.onConfigured();
      auth = StreamController<AuthState>.broadcast();
      whenListen(authBloc, auth.stream, initialState: AuthAuthenticated(_user));
      addTearDown(auth.close);
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    /// Le BLoC naît dans la zone du test : créé dans `setUp`, ses
    /// microtâches échapperaient aux `pump`.
    Future<void> askAsA(WidgetTester tester) async {
      real = AssistantBloc(repository, _MockSupportRepository(), analytics);
      addTearDown(real.close);
      getIt.unregister<AssistantBloc>();
      getIt.registerSingleton<AssistantBloc>(real);
      await pump(tester);
      real.add(const AssistantQuestionSubmitted('Question de A', locale: 'fr'));
      await settle(tester);
      expect(real.state.messages, hasLength(2));
      expect(real.state.available, isTrue);
    }

    testWidgets('A, question, déconnexion, connexion de B : conversation '
        'vierge', (tester) async {
      await askAsA(tester);
      auth.add(const AuthInitial());
      await settle(tester);
      auth.add(AuthAuthenticated(_otherUser));
      await settle(tester);
      expect(real.state.messages, isEmpty);
      expect(real.state.isSending, isFalse);
    });

    testWidgets('A puis B sans déconnexion visible : conversation vierge et '
        'nouvelle sonde pour B', (tester) async {
      await askAsA(tester);
      verify(() => repository.status()).called(1);
      auth.add(AuthAuthenticated(_otherUser));
      await settle(tester);
      expect(real.state.messages, isEmpty);
      verify(() => repository.status()).called(1);
      expect(real.state.available, isTrue);
    });

    for (final end in <AuthState>[
      const AuthAccountDeleted(),
      const AuthGuestSessionReady(),
    ]) {
      testWidgets('$end : conversation vierge', (tester) async {
        await askAsA(tester);
        auth.add(end);
        await settle(tester);
        expect(real.state.messages, isEmpty);
      });
    }

    testWidgets('verrou PIN puis déverrouillage du même compte : historique '
        'conservé', (tester) async {
      await askAsA(tester);
      auth.add(const AuthLocked());
      await settle(tester);
      auth.add(AuthAuthenticated(_user));
      await settle(tester);
      expect(real.state.messages, hasLength(2));
    });

    testWidgets('rafraîchissement du même compte : historique conservé', (
      tester,
    ) async {
      await askAsA(tester);
      auth.add(const AuthLoading());
      await settle(tester);
      auth.add(AuthProfileUpdated(_user));
      await settle(tester);
      auth.add(AuthAuthenticated(_user));
      await settle(tester);
      expect(real.state.messages, hasLength(2));
    });
  });
}
