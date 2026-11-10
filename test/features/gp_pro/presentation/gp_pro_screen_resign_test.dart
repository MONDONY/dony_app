import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:dony/features/gp_pro/presentation/screens/gp_pro_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements GpProRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _gpProUser = UserModel(
  id: 'u1',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  gpPro: true,
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  late _MockAuthBloc auth;
  final fr = lookupAppLocalizations(AppL10n.fr);

  setUpAll(() => registerFallbackValue(_FakeAuthEvent()));

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    analytics = _MockAnalytics();
    auth = _MockAuthBloc();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => auth.isClosed).thenReturn(false);
    when(() => auth.state).thenReturn(const AuthAuthenticated(_gpProUser));
    when(
      () => repo.fetchStatus(),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.active));
  });

  /// Profil (page de départ) puis écran GP Pro poussé par-dessus.
  Future<void> open(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    bool directEntry = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      // `directEntry` : ouvert par `go` (notification, lien profond), pile vide.
      initialLocation: directEntry ? '/profile/gp-pro' : '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('Profil'),
                TextButton(
                  onPressed: () => context.push('/profile/gp-pro'),
                  child: const Text('ouvrir'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Profil (onglet)')),
        ),
        GoRoute(
          path: '/profile/gp-pro',
          builder: (context, _) => BlocProvider(
            create: (_) => GpProCubit(repo, analytics)..load(),
            child: const GpProScreen(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    if (!directEntry) await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Finder resignButton(String label) => find.widgetWithText(DonyButton, label);

  testWidgets('vue « Vous êtes GP Pro » : « Redevenir particulier » dans la '
      'barre du bas', (tester) async {
    await open(tester);

    expect(find.text(fr.gpProActiveTitle), findsOneWidget);
    expect(resignButton('Redevenir particulier'), findsOneWidget);
    expect(find.byKey(const Key('gp_pro_resign')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demande en validation : pas de « Redevenir particulier » '
      '(« Annuler ma demande » existe déjà)', (tester) async {
    when(
      () => repo.fetchStatus(),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
    await open(tester);

    expect(resignButton('Redevenir particulier'), findsNothing);
    expect(find.text(fr.gpProCancel), findsOneWidget);
  });

  testWidgets('confirmation fermée sans bouton : rien n\'est retiré', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(resignButton('Redevenir particulier'));
    await tester.pumpAndSettle();
    expect(find.text('Redevenir particulier ?'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    verifyNever(() => repo.resign());
    expect(find.text(fr.gpProActiveTitle), findsOneWidget);
  });

  testWidgets('confirmé : resign, retour au profil, profil mis à jour sans '
      'badge, confirmation discrète', (tester) async {
    when(
      () => repo.resign(),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.none));
    await open(tester);
    await tester.tap(resignButton('Redevenir particulier'));
    await tester.pumpAndSettle();
    when(
      () => repo.fetchStatus(),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.none));

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Redevenir particulier'),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => repo.resign()).called(1);
    // Retour au profil.
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text(fr.gpProActiveTitle), findsNothing);
    expect(find.text('Vous êtes de nouveau particulier.'), findsOneWidget);
    // Profil local sans badge, puis rechargé.
    final events = verify(() => auth.add(captureAny())).captured;
    expect(events, hasLength(2));
    final synced = events[0] as AuthUserSynced;
    expect(synced.user.gpPro, isFalse);
    expect(events[1], isA<AuthProfileRefreshRequested>());
    verify(
      () => analytics.logEvent(
        'gp_pro_resigned',
        properties: any(named: 'properties'),
      ),
    ).called(1);
  });

  testWidgets('ouvert par un lien (pile vide) : après le retrait, arrivée sur '
      'l\'onglet Profil', (tester) async {
    when(
      () => repo.resign(),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.none));
    await open(tester, directEntry: true);
    expect(find.text(fr.gpProActiveTitle), findsOneWidget);
    await tester.tap(resignButton('Redevenir particulier'));
    await tester.pumpAndSettle();
    when(
      () => repo.fetchStatus(),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.none));

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Redevenir particulier'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil (onglet)'), findsOneWidget);
    expect(find.text(fr.gpProActiveTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retrait refusé : on reste sur l\'écran, message d\'erreur, '
      'bouton réactivé', (tester) async {
    when(() => repo.resign()).thenThrow(const GpProException('network'));
    await open(tester);
    await tester.tap(resignButton('Redevenir particulier'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Redevenir particulier'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(fr.gpProActiveTitle), findsOneWidget);
    expect(find.text(fr.gpProErrorNetwork), findsOneWidget);
    expect(
      tester
          .widget<DonyButton>(resignButton('Redevenir particulier'))
          .onPressed,
      isNotNull,
    );
    verifyNever(() => auth.add(any(that: isA<AuthUserSynced>())));
  });

  testWidgets('anglais, 360 dp : « Back to individual » et sa confirmation '
      'sans exception', (tester) async {
    await open(tester, locale: AppL10n.en);

    final button = resignButton('Back to individual');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, lessThan(64));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Back to individual?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
