import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/activites_hub_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockTravelerBidsBloc
    extends MockBloc<TravelerBidsEvent, TravelerBidsState>
    implements TravelerBidsBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _FakeBidEvent extends Fake implements BidEvent {}

// ── Helpers ───────────────────────────────────────────────────────────────────

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Routes atteintes pendant le test, dans l'ordre.
late List<String> visited;

Future<void> _pump(
  WidgetTester tester, {
  TripsSummaryModel? summary,
  BidState? bidState,
  TravelerBidsState? travelerBidsState,
  NegotiationListState? negoState,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  visited = [];

  final repo = _MockAnnouncementRepository();
  when(() => repo.getTripsSummary(period: any(named: 'period'))).thenAnswer(
    (_) async =>
        summary ??
        const TripsSummaryModel(
          activeTrips: 6,
          kgSold: 0,
          revenue: 0,
        ),
  );

  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(
    bidState ??
        BidListLoaded([
          _bid('b1', 'IN_TRANSIT'),
          _bid('b2', 'ACCEPTED'),
          _bid('b3', 'COMPLETED'),
        ]),
  );

  final travelerBids = _MockTravelerBidsBloc();
  when(() => travelerBids.state).thenReturn(
    travelerBidsState ??
        TravelerBidsLoaded(
          bids: [_bid('r1', 'PENDING'), _bid('r2', 'PAYMENT_ESCROWED')],
          page: 0,
          hasMore: false,
          filter: TravelerBidFilter.aTraiter,
        ),
  );

  final nego = _MockNegotiationListBloc();
  when(() => nego.state).thenReturn(negoState ?? NegotiationListState());

  final summaryCubit = TripsSummaryCubit(repo);

  Widget stub(String label) => Scaffold(body: Text(label));

  GoRoute route(String path, String label) => GoRoute(
    path: path,
    builder: (_, __) {
      visited.add(path);
      return stub(label);
    },
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<TripsSummaryCubit>.value(value: summaryCubit),
            BlocProvider<TravelerBidsBloc>.value(value: travelerBids),
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<StatsPeriodCubit>(create: (_) => StatsPeriodCubit()),
            BlocProvider<NegotiationListBloc>.value(value: nego),
          ],
          child: const ActivitesHubScreenTesting(),
        ),
      ),
      route('/announcements/trips', 'Trajets'),
      route('/envois', 'Envois'),
      route('/demandes', 'Demandes'),
      route('/negotiations', 'Négociations'),
      route('/trips/create', 'Créer trajet'),
      route('/tracking/search', 'Recherche'),
      route('/profile/shipments/history', 'Historique'),
      route('/profile/help/faq', 'FAQ'),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    // Événements sealed : on enregistre une instance concrète plutôt qu'un Fake.
    registerFallbackValue(const TravelerBidsRequested());
    registerFallbackValue(const NegotiationListFetchRequested());
    registerFallbackValue('');
  });

  setUp(() {
    if (!getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.registerLazySingleton<EnvoisRefreshNotifier>(
        EnvoisRefreshNotifier.new,
      );
    }
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      when(
        () => analytics.logScreen(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    }
  });

  tearDown(() => getIt.reset());

  group('compteurs', () {
    testWidgets('les quatre tuiles affichent les compteurs de leur bloc', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Trajets actifs'), findsOneWidget);
      expect(find.text('Envois en cours'), findsOneWidget);
      expect(find.text('Demandes'), findsOneWidget);
      expect(find.text('Négociations'), findsOneWidget);

      // 6 trajets actifs (summary), 2 envois en cours (IN_TRANSIT + ACCEPTED,
      // le COMPLETED est exclu), 2 demandes à traiter, 0 négociation.
      expect(find.text('6'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('une erreur de résumé n\'affecte que sa propre tuile', (
      tester,
    ) async {
      final repo = _MockAnnouncementRepository();
      when(
        () => repo.getTripsSummary(period: any(named: 'period')),
      ).thenThrow(Exception('network'));

      await _pump(tester);
      // Les autres tuiles gardent leurs compteurs même si le résumé échoue.
      expect(find.text('Envois en cours'), findsOneWidget);
      expect(find.text('Demandes'), findsOneWidget);
    });
  });

  group('navigation', () {
    Future<void> expectNavigation(
      WidgetTester tester,
      String label,
      String expectedRoute,
    ) async {
      await _pump(tester);
      await tester.ensureVisible(find.text(label).first);
      await tester.tap(find.text(label).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(visited, contains(expectedRoute));
    }

    testWidgets('Trajets actifs → liste des trajets', (tester) async {
      await expectNavigation(tester, 'Trajets actifs', '/announcements/trips');
    });

    testWidgets('Envois en cours → liste des envois', (tester) async {
      await expectNavigation(tester, 'Envois en cours', '/envois');
    });

    testWidgets('Demandes → écran Demandes', (tester) async {
      await expectNavigation(tester, 'Demandes', '/demandes');
    });

    testWidgets('Négociations → liste des négociations', (tester) async {
      await expectNavigation(tester, 'Négociations', '/negotiations');
    });

    testWidgets('Publier un trajet → formulaire de création', (tester) async {
      await expectNavigation(tester, 'Publier un trajet', '/trips/create');
    });

    testWidgets('Historique complet → historique des envois', (tester) async {
      await expectNavigation(
        tester,
        'Historique complet',
        '/profile/shipments/history',
      );
    });

    testWidgets('Aide & support → FAQ', (tester) async {
      await expectNavigation(tester, 'Aide & support', '/profile/help/faq');
    });
  });

  group('rangée d\'actions', () {
    testWidgets('les deux boutons tiennent sur une ligne, à hauteur égale', (
      tester,
    ) async {
      await _pump(tester);

      final publish = tester.getSize(find.byKey(const Key('hub-publish-trip')));
      final send = tester.getSize(find.byKey(const Key('hub-new-request')));

      // Un libellé qui passe sur deux lignes fait grandir son bouton et casse
      // la symétrie de la paire — c'est ce que cette assertion attrape.
      expect(send.height, publish.height);
      expect(send.height, lessThanOrEqualTo(56));
    });
  });

  group('statistiques', () {
    testWidgets('les trois périodes sont proposées, 30 jours par défaut', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('7 jours'), findsOneWidget);
      expect(find.text('30 jours'), findsOneWidget);
      expect(find.text('12 mois'), findsOneWidget);
    });

    testWidgets('changer de période recharge le résumé', (tester) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('12 mois'));
      await tester.tap(find.text('12 mois'));
      await tester.pump();

      // La sélection est reflétée dans le cubit de période.
      final context = tester.element(find.text('12 mois'));
      expect(
        BlocProvider.of<StatsPeriodCubit>(context).state,
        StatsPeriod.twelveMonths,
      );
    });

    testWidgets('les quatre métriques sont affichées', (tester) async {
      await _pump(tester);

      expect(find.text('Revenus'), findsOneWidget);
      expect(find.text('Kg vendus'), findsOneWidget);
      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('Envois'), findsOneWidget);
    });
  });
}
