import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_status_signal.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:dony/features/profile/presentation/widgets/profile_gp_pro_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockGpProRepository extends Mock implements GpProRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _user = UserModel(
  id: 'u1',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

void main() {
  late _MockGpProRepository repo;
  late _MockAnalytics analytics;
  late _MockAuthBloc auth;
  late StreamController<AuthState> authStates;
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUpAll(() => registerFallbackValue(_FakeAuthEvent()));

  setUp(() {
    repo = _MockGpProRepository();
    analytics = _MockAnalytics();
    auth = _MockAuthBloc();
    authStates = StreamController<AuthState>.broadcast();
    addTearDown(authStates.close);
    when(
      () => repo.fetchStatus(),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.none));
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => auth.isClosed).thenReturn(false);
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerFactory<GpProCubit>(() => GpProCubit(repo, analytics));
  });

  tearDown(() async => getIt.reset());

  Future<void> pumpNoSettle(
    WidgetTester tester,
    UserModel user, {
    Locale locale = AppL10n.fr,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              // Le Profil reconstruit la section avec l'utilisateur courant.
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) =>
                    ProfileGpProSection(user: state.currentUser ?? user),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/profile/gp-pro',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: context.pop,
              child: const Text('écran GP Pro'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    whenListen<AuthState>(
      auth,
      authStates.stream,
      initialState: AuthAuthenticated(user),
    );
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
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester,
    UserModel user, {
    Locale locale = AppL10n.fr,
    double width = 360,
  }) async {
    await pumpNoSettle(tester, user, locale: locale, width: width);
    await tester.pumpAndSettle();
  }

  group('trois états de la ligne', () {
    testWidgets('pas GP Pro, aucune demande : « Devenir GP Pro » et son '
        'sous-titre, sans pastille', (tester) async {
      await pump(tester, _user);

      expect(find.text(fr.profileSectionGpPro), findsOneWidget);
      expect(find.text('Devenir GP Pro'), findsOneWidget);
      expect(find.text(fr.profileGpProBecomeSubtitle), findsOneWidget);
      expect(find.text('Actif'), findsNothing);
      expect(find.text('En validation'), findsNothing);
      verify(() => repo.fetchStatus()).called(1);
    });

    for (final state in [GpProState.pending, GpProState.awaitingKyc]) {
      testWidgets('demande ouverte (${state.wire}) : « Demande GP Pro » et '
          'pastille « En validation »', (tester) async {
        when(
          () => repo.fetchStatus(),
        ).thenAnswer((_) async => GpProStatus(state: state));
        await pump(tester, _user);

        expect(find.text('Demande GP Pro'), findsOneWidget);
        expect(find.text('En validation'), findsOneWidget);
        expect(find.text('Devenir GP Pro'), findsNothing);
      });
    }

    testWidgets('GP Pro validé : « GP Pro » et pastille « Actif », sans '
        'aucune lecture réseau', (tester) async {
      await pump(tester, _user.copyWith(gpPro: true));

      expect(find.text('GP Pro'), findsWidgets);
      expect(find.text('Actif'), findsOneWidget);
      expect(find.text('Devenir GP Pro'), findsNothing);
      verifyNever(() => repo.fetchStatus());
    });

    testWidgets('demande refusée : « Devenir GP Pro »', (tester) async {
      when(
        () => repo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.rejected));
      await pump(tester, _user);
      expect(find.text('Devenir GP Pro'), findsOneWidget);
    });

    testWidgets('lecture en échec : « Devenir GP Pro », aucune exception', (
      tester,
    ) async {
      when(() => repo.fetchStatus()).thenThrow(const GpProException('network'));
      await pump(tester, _user);

      expect(find.text('Devenir GP Pro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cubit absent du graphe : « Devenir GP Pro »', (tester) async {
      getIt.unregister<GpProCubit>();
      await pump(tester, _user);

      expect(find.text('Devenir GP Pro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('chargement', () {
    testWidgets('pendant la première lecture : ligne neutre, pas de faux '
        '« Devenir GP Pro », puis l\'état réel', (tester) async {
      final gate = Completer<GpProStatus>();
      when(() => repo.fetchStatus()).thenAnswer((_) => gate.future);
      await pumpNoSettle(tester, _user);

      expect(find.text('GP Pro'), findsOneWidget);
      expect(find.text('Devenir GP Pro'), findsNothing);
      expect(find.text(fr.profileGpProBecomeSubtitle), findsNothing);
      expect(find.text('En validation'), findsNothing);

      // Un tap pendant la lecture trace « loading », jamais « none ».
      await tester.tap(find.byKey(const Key('profile-gp-pro-row')));
      await tester.pumpAndSettle();
      verify(
        () => analytics.logEvent(
          'profile_gp_pro_row_tapped',
          properties: {'state': 'loading'},
        ),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(
          'profile_gp_pro_row_tapped',
          properties: {'state': 'none'},
        ),
      );
      await tester.tap(find.text('écran GP Pro'));
      await tester.pumpAndSettle();

      gate.complete(const GpProStatus(state: GpProState.pending));
      await tester.pumpAndSettle();
      expect(find.text('Demande GP Pro'), findsOneWidget);
    });
  });

  group('la ligne ne reste pas périmée', () {
    testWidgets('demande envoyée ailleurs (changement de statut GP Pro) : '
        '« Demande GP Pro »', (tester) async {
      await pump(tester, _user);
      expect(find.text('Devenir GP Pro'), findsOneWidget);

      when(
        () => repo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
      notifyGpProStatusChanged();
      await tester.pumpAndSettle();

      expect(find.text('Demande GP Pro'), findsOneWidget);
      expect(find.text('En validation'), findsOneWidget);
    });

    testWidgets('demande refusée côté équipe, reprise de l\'app : « Devenir '
        'GP Pro »', (tester) async {
      when(
        () => repo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
      await pump(tester, _user);
      expect(find.text('Demande GP Pro'), findsOneWidget);

      when(
        () => repo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.rejected));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Devenir GP Pro'), findsOneWidget);
      expect(find.text('Demande GP Pro'), findsNothing);
    });

    testWidgets('nouveau profil de l\'AuthBloc : la demande est relue', (
      tester,
    ) async {
      await pump(tester, _user);
      when(() => repo.fetchStatus()).thenAnswer(
        (_) async => const GpProStatus(state: GpProState.awaitingKyc),
      );

      authStates.add(AuthProfileUpdated(_user.copyWith(city: 'Lyon')));
      await tester.pumpAndSettle();

      expect(find.text('Demande GP Pro'), findsOneWidget);
    });

    testWidgets('user.gpPro passe de vrai à faux : « Devenir GP Pro »', (
      tester,
    ) async {
      await pump(tester, _user.copyWith(gpPro: true));
      expect(find.text('Actif'), findsOneWidget);

      authStates.add(const AuthProfileUpdated(_user));
      await tester.pumpAndSettle();

      expect(find.text('Actif'), findsNothing);
      expect(find.text('Devenir GP Pro'), findsOneWidget);
    });

    testWidgets('plusieurs signaux d\'affilée : une seule relecture à la '
        'fois', (tester) async {
      await pump(tester, _user);
      final gate = Completer<GpProStatus>();
      when(() => repo.fetchStatus()).thenAnswer((_) => gate.future);

      notifyGpProStatusChanged();
      notifyGpProStatusChanged();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // 1 lecture au montage + 1 seule relance, les deux autres ignorées.
      verify(() => repo.fetchStatus()).called(2);
      gate.complete(const GpProStatus(state: GpProState.none));
      await tester.pumpAndSettle();
    });
  });

  group('sous-titre', () {
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('[${locale.languageCode}] tient sur deux lignes à 360 dp, '
          'sans ellipse', (tester) async {
        await pump(tester, _user, locale: locale);
        final l = locale == AppL10n.fr ? fr : en;

        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(l.profileGpProBecomeSubtitle),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(l.profileGpProBecomeSubtitle.length, lessThanOrEqualTo(60));
      });
    }
  });

  group('tap', () {
    testWidgets('ouvre /profile/gp-pro, trace l\'événement sans donnée '
        'd\'entreprise, relit le profil et la demande au retour', (
      tester,
    ) async {
      await pump(tester, _user);

      await tester.tap(find.byKey(const Key('profile-gp-pro-row')));
      await tester.pumpAndSettle();
      expect(find.text('écran GP Pro'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          'profile_gp_pro_row_tapped',
          properties: {'state': 'none'},
        ),
      ).called(1);

      // La demande part depuis l'écran GP Pro.
      when(
        () => repo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
      await tester.tap(find.text('écran GP Pro'));
      await tester.pumpAndSettle();

      verify(
        () => auth.add(any(that: isA<AuthProfileRefreshRequested>())),
      ).called(1);
      expect(find.text('Demande GP Pro'), findsOneWidget);
      expect(find.text('En validation'), findsOneWidget);
    });

    testWidgets('état « active » tracé', (tester) async {
      await pump(tester, _user.copyWith(gpPro: true));
      await tester.tap(find.byKey(const Key('profile-gp-pro-row')));
      await tester.pumpAndSettle();
      verify(
        () => analytics.logEvent(
          'profile_gp_pro_row_tapped',
          properties: {'state': 'active'},
        ),
      ).called(1);
    });

    testWidgets('état « open » tracé', (tester) async {
      when(
        () => repo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
      await pump(tester, _user);
      await tester.tap(find.byKey(const Key('profile-gp-pro-row')));
      await tester.pumpAndSettle();
      verify(
        () => analytics.logEvent(
          'profile_gp_pro_row_tapped',
          properties: {'state': 'open'},
        ),
      ).called(1);
    });
  });

  group('360 dp, français et anglais', () {
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      final code = locale.languageCode;
      final l = locale == AppL10n.fr ? fr : en;
      for (final state in ['none', 'open', 'active']) {
        testWidgets('[$code] $state : sans exception', (tester) async {
          if (state == 'open') {
            when(() => repo.fetchStatus()).thenAnswer(
              (_) async => const GpProStatus(state: GpProState.pending),
            );
          }
          await pump(
            tester,
            state == 'active' ? _user.copyWith(gpPro: true) : _user,
            locale: locale,
          );
          expect(tester.takeException(), isNull);
          expect(find.text(l.profileSectionGpPro), findsOneWidget);
          switch (state) {
            case 'none':
              expect(find.text(l.profileGpProBecome), findsOneWidget);
            case 'open':
              expect(find.text(l.profileGpProApplication), findsOneWidget);
              expect(find.text(l.profileTravelerStatusPending), findsOneWidget);
            default:
              expect(find.text(l.profileGpProActivePill), findsOneWidget);
          }
        });
      }
    }
  });
}
