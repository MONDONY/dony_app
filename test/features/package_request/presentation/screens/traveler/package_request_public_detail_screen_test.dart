import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockPriceEstimationRepository extends Mock
    implements PriceEstimationRepository {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _senderId = 'sender-001';

const _sender = UserModel(
  id: _senderId,
  roles: [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

PackageRequest _makeRequest({String? viewerThreadId}) => PackageRequest(
  id: 'pr-owner-test',
  senderId: _senderId,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: PackageRequestStatus.open,
  createdAt: DateTime(2026, 6),
  viewerThreadId: viewerThreadId,
);

// ── Pump helper (pile navigable) ─────────────────────────────────────────────
//
// Reproduit la topologie de `app.dart` : `AuthBloc` est AU-DESSUS de
// `MaterialApp.router`. Nécessaire pour tester la redirection propriétaire →
// « Ma demande », qui quitte l'écran (pop) avant de pousser la destination.
Future<GoRouter> _pumpRouted(
  WidgetTester tester, {
  required _MockAuthBloc authBloc,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => const Scaffold(body: Text('HOST')),
      ),
      GoRoute(
        path: '/public',
        builder: (ctx, _) =>
            const PackageRequestPublicDetailScreen(requestId: 'pr-owner-test'),
      ),
      GoRoute(
        path: '/package-requests/:id',
        builder: (ctx, state) =>
            Scaffold(body: Text('MA DEMANDE ${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    ),
  );
  unawaited(router.push('/public'));
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

void main() {
  late _MockPackageRequestRepository repo;
  late _MockAnalyticsService analytics;
  late _MockAuthBloc authBloc;

  setUp(() {
    repo = _MockPackageRequestRepository();
    analytics = _MockAnalyticsService();
    authBloc = _MockAuthBloc();

    when(() => repo.getById(any())).thenAnswer((_) async => _makeRequest());

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    if (getIt.isRegistered<PackageRequestRepository>()) {
      getIt.unregister<PackageRequestRepository>();
    }
    getIt.registerLazySingleton<PackageRequestRepository>(() => repo);

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<PackageRequestRepository>()) {
      getIt.unregister<PackageRequestRepository>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    authBloc.close();
  });

  // ── Propriétaire authentifié (deep link `yadony://demande/{id}`) ───────────
  testWidgets(
    'propriétaire authentifié → renvoyé vers « Ma demande », écran quitté',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_sender));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_sender),
      );

      await _pumpRouted(tester, authBloc: authBloc);
      await tester.pumpAndSettle();

      expect(find.byType(PackageRequestPublicDetailScreen), findsNothing);
      expect(find.text('MA DEMANDE pr-owner-test'), findsOneWidget);
    },
  );

  // ── Visiteur non propriétaire ────────────────────────────────────────────
  testWidgets(
    'visiteur authentifié non propriétaire → reste sur la vue publique',
    (tester) async {
      const visitor = UserModel(
        id: 'visitor-042',
        roles: [],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(visitor));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(visitor),
      );

      await _pumpRouted(tester, authBloc: authBloc);
      await tester.pumpAndSettle();

      expect(find.byType(PackageRequestPublicDetailScreen), findsOneWidget);
      expect(find.text('Demande d\'envoi'), findsOneWidget);
    },
  );

  // ── Invité (session anonyme) ─────────────────────────────────────────────
  testWidgets('session invité → reste sur la vue publique', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthGuestSessionReady(),
    );

    await _pumpRouted(tester, authBloc: authBloc);
    await tester.pumpAndSettle();

    expect(find.byType(PackageRequestPublicDetailScreen), findsOneWidget);
  });

  // ── Auth pas encore résolue (démarrage à froid via lien profond) ───────────
  // L'AuthBloc peut encore être en `AuthInitial` quand la demande a déjà
  // chargé : classer alors le propriétaire en visiteur enverrait à tort une
  // redirection prématurée, ou pire, aucune redirection du tout une fois
  // l'auth résolue si le listener n'était pas en place. On vérifie ici que
  // rien ne bouge tant que le verdict n'est pas tranché.
  testWidgets(
    'auth pas encore résolue → ne redirige pas, reste sur la vue publique',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthInitial());
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthInitial(),
      );

      await _pumpRouted(tester, authBloc: authBloc);
      await tester.pumpAndSettle();

      expect(find.byType(PackageRequestPublicDetailScreen), findsOneWidget);
      expect(find.text('MA DEMANDE pr-owner-test'), findsNothing);
    },
  );

  // ── Résolution tardive de l'auth (démarrage à froid) ────────────────────
  // La demande a déjà chargé pendant que l'AuthBloc était encore en
  // `AuthInitial` ; une fois l'auth résolue en propriétaire, le
  // `BlocListener<AuthBloc>` doit rattraper la redirection.
  testWidgets(
    'auth résolue après coup en propriétaire → redirection rattrapée',
    (tester) async {
      final authController = StreamController<AuthState>();
      addTearDown(authController.close);
      when(() => authBloc.state).thenReturn(const AuthInitial());
      whenListen(
        authBloc,
        authController.stream,
        initialState: const AuthInitial(),
      );

      final router = await _pumpRouted(tester, authBloc: authBloc);
      await tester.pumpAndSettle();
      expect(find.byType(PackageRequestPublicDetailScreen), findsOneWidget);

      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_sender));
      authController.add(const AuthAuthenticated(_sender));
      await tester.pumpAndSettle();

      expect(find.byType(PackageRequestPublicDetailScreen), findsNothing);
      expect(find.text('MA DEMANDE pr-owner-test'), findsOneWidget);
      // Pile propre : `/` en dessous, `/package-requests/:id` au sommet — la
      // vue publique a bien été retirée (pop), pas simplement recouverte.
      expect(router.canPop(), isTrue);
    },
  );

  // ── Échec de chargement ───────────────────────────────────────────────────
  testWidgets(
    'échec de chargement → texte du catalogue affiché, jamais le message brut',
    (tester) async {
      when(() => repo.getById(any())).thenThrow(Exception('boom'));
      when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthGuestSessionReady(),
      );

      await _pumpRouted(tester, authBloc: authBloc);
      await tester.pumpAndSettle();

      expect(
        find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
      expect(find.text('boom'), findsNothing);
    },
  );

  testWidgets(
    'anglais : échec de chargement affiche le texte du catalogue, jamais le '
    'message brut',
    (tester) async {
      useEnglish();
      when(
        () => repo.getById(any()),
      ).thenThrow(Exception('raw technical detail'));
      when(() => authBloc.state).thenReturn(const AuthGuestSessionReady());
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthGuestSessionReady(),
      );

      await _pumpRouted(tester, authBloc: authBloc);
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('raw technical detail'), findsNothing);
    },
  );

  // ── Voyageur : CTA rechargé à la fermeture de la sheet d'offre ────────────
  //
  // Bug terrain (2026-09-18) : le détail n'était chargé qu'une fois. Après
  // « Offre envoyée », la négo était poussée par-dessus et, au retour, le
  // CTA proposait encore un trajet alors qu'un thread existait déjà.
  group('voyageur, sheet d\'offre', () {
    late _MockNegotiationBloc negoBloc;
    late _MockPriceEstimationRepository priceRepo;
    late _MockAnnouncementRepository announcementRepo;

    setUpAll(() async {
      await initializeDateFormatting('fr');
    });

    setUp(() {
      negoBloc = _MockNegotiationBloc();
      priceRepo = _MockPriceEstimationRepository();
      announcementRepo = _MockAnnouncementRepository();
      when(() => negoBloc.state).thenReturn(const NegotiationInitial());
      when(
        () => negoBloc.stream,
      ).thenAnswer((_) => const Stream<NegotiationState>.empty());
      when(
        () => priceRepo.estimate(
          from: any(named: 'from'),
          to: any(named: 'to'),
          weight: any(named: 'weight'),
          currency: any(named: 'currency'),
        ),
      ).thenThrow(Exception('no estimate'));
      when(() => announcementRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
      );
      if (getIt.isRegistered<NegotiationBloc>()) {
        getIt.unregister<NegotiationBloc>();
      }
      if (getIt.isRegistered<PriceEstimationRepository>()) {
        getIt.unregister<PriceEstimationRepository>();
      }
      if (getIt.isRegistered<AnnouncementRepository>()) {
        getIt.unregister<AnnouncementRepository>();
      }
      getIt.registerFactory<NegotiationBloc>(() => negoBloc);
      getIt.registerLazySingleton<PriceEstimationRepository>(() => priceRepo);
      getIt.registerLazySingleton<AnnouncementRepository>(
        () => announcementRepo,
      );
    });

    tearDown(() {
      if (getIt.isRegistered<NegotiationBloc>()) {
        getIt.unregister<NegotiationBloc>();
      }
      if (getIt.isRegistered<PriceEstimationRepository>()) {
        getIt.unregister<PriceEstimationRepository>();
      }
      if (getIt.isRegistered<AnnouncementRepository>()) {
        getIt.unregister<AnnouncementRepository>();
      }
    });

    testWidgets(
      'sheet fermée → détail rechargé, CTA « Voir ma négociation », sans spinner',
      (tester) async {
        const visitor = UserModel(
          id: 'visitor-042',
          roles: [],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        );
        when(() => authBloc.state).thenReturn(const AuthAuthenticated(visitor));
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: const AuthAuthenticated(visitor),
        );
        // 1er appel : pas de thread. 2e appel (rechargement) : thread créé.
        var calls = 0;
        final reloadGate = Completer<PackageRequest>();
        when(() => repo.getById(any())).thenAnswer((_) {
          calls++;
          return calls == 1 ? Future.value(_makeRequest()) : reloadGate.future;
        });

        await _pumpRouted(tester, authBloc: authBloc);
        await tester.pumpAndSettle();
        expect(find.text('Proposer mon trajet'), findsOneWidget);

        await tester.tap(find.text('Proposer mon trajet'));
        await tester.pumpAndSettle();
        expect(find.text('Faire une offre'), findsOneWidget);

        final closeBtn = find.ancestor(
          of: find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
          matching: find.byType(IconButton),
        );
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        // Rechargement en vol : la fiche reste affichée, pas de spinner.
        expect(calls, 2);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Proposer mon trajet'), findsOneWidget);

        reloadGate.complete(_makeRequest(viewerThreadId: 'thread-1'));
        await tester.pumpAndSettle();
        expect(find.text('Voir ma négociation'), findsOneWidget);
        expect(find.text('Proposer mon trajet'), findsNothing);
      },
    );
  });
}
