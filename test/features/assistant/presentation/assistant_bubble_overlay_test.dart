import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/app/main_shell.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_bubble_overlay.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAssistantBloc extends MockBloc<AssistantEvent, AssistantState>
    implements AssistantBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPrefsBloc extends MockBloc<AppPreferencesEvent, AppPreferencesState>
    implements AppPreferencesBloc {}

class _FakeAppPreferencesEvent extends Fake implements AppPreferencesEvent {}

const _bubbleKey = ValueKey('assistant-bubble');
const _homeButtonKey = ValueKey('home-button');

int _homeBuilds = 0;
int _homeTaps = 0;
String? _assistantSource;

final _user = UserModel.fromJson(const {
  'id': 'u1',
  'roles': ['SENDER'],
  'kycStatus': 'VERIFIED',
});

void main() {
  late _MockAssistantBloc assistantBloc;
  late _MockAuthBloc authBloc;
  late _MockPrefsBloc prefsBloc;
  late GoRouter router;

  setUpAll(() {
    registerFallbackValue(_FakeAppPreferencesEvent());
    registerFallbackValue(const AssistantResetRequested());
  });

  setUp(() {
    _homeBuilds = 0;
    _homeTaps = 0;
    _assistantSource = null;
    assistantBloc = _MockAssistantBloc();
    authBloc = _MockAuthBloc();
    prefsBloc = _MockPrefsBloc();
    when(() => assistantBloc.state).thenReturn(const AssistantState());
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
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) {
            _homeBuilds++;
            return Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  key: _homeButtonKey,
                  onPressed: () => _homeTaps++,
                  child: const Text('home'),
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
                    AssistantBubbleOverlay(router: router),
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
      verifyNever(() => assistantBloc.add(any()));
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
}
