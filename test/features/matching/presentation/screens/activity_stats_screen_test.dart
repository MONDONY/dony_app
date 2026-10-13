import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/kg_sold_cubit.dart';
import 'package:dony/features/matching/bloc/revenue_details_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/activity_stats_screen.dart';
import 'package:dony/features/matching/presentation/widgets/kg_sold_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/revenue_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

/// URIs complètes atteintes pendant le test, dans l'ordre.
late List<String> visitedUris;
late AnnouncementRepository repo;
late AnalyticsService analytics;
late int refreshes;

Future<void> _pump(
  WidgetTester tester, {
  TripsSummaryModel? summary,
  KgSoldModel? kgSold,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  visitedUris = [];
  when(() => repo.getTripsSummary(period: any(named: 'period'))).thenAnswer(
    (_) async =>
        summary ??
        const TripsSummaryModel(activeTrips: 6, kgSold: 0, revenue: 0),
  );
  when(() => repo.getRevenueDetails(period: any(named: 'period'))).thenAnswer(
    (_) async =>
        const RevenueDetailsModel(period: '30d', deliveries: 0, groups: []),
  );
  when(() => repo.getKgSold(period: any(named: 'period'))).thenAnswer(
    (_) async =>
        kgSold ??
        const KgSoldModel(period: '30d', totalKg: 0, parcels: 0, trips: []),
  );

  GoRoute route(String path) => GoRoute(
    path: path,
    builder: (_, state) {
      visitedUris.add(state.uri.toString());
      return Scaffold(body: Text('stub $path'));
    },
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ActivityStatsScreen()),
      route('/announcements/trips'),
      route('/announcements/:id/trip'),
      route('/envois'),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue('');
    // La feuille Kg vendus date ses lignes en français.
    initializeDateFormatting('fr');
  });

  setUp(() {
    repo = _MockAnnouncementRepository();
    analytics = _MockAnalyticsService();
    refreshes = 0;
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt
      ..registerLazySingleton<AnalyticsService>(() => analytics)
      ..registerFactory<TripsSummaryCubit>(() => TripsSummaryCubit(repo))
      ..registerFactory<StatsPeriodCubit>(StatsPeriodCubit.new)
      ..registerFactory<RevenueDetailsCubit>(() => RevenueDetailsCubit(repo))
      ..registerFactory<KgSoldCubit>(() => KgSoldCubit(repo))
      ..registerLazySingleton<EnvoisRefreshNotifier>(() {
        final notifier = EnvoisRefreshNotifier();
        notifier.addListener(() => refreshes++);
        return notifier;
      });
  });

  tearDown(() => getIt.reset());

  testWidgets(
    'titre « Mes statistiques », trois périodes, 30 jours par défaut',
    (tester) async {
      await _pump(tester);

      expect(find.text('Mes statistiques'), findsOneWidget);
      expect(find.text('7 jours'), findsOneWidget);
      expect(find.text('30 jours'), findsOneWidget);
      expect(find.text('12 mois'), findsOneWidget);
      verify(() => repo.getTripsSummary(period: '30d')).called(1);
    },
  );

  testWidgets('changer de période recharge le résumé et le trace', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('12 mois'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('12 mois'));
    expect(
      BlocProvider.of<StatsPeriodCubit>(context).state,
      StatsPeriod.twelveMonths,
    );
    verify(() => repo.getTripsSummary(period: '12m')).called(1);
    verify(
      () => analytics.logEvent(AnalyticsEvents.activitesHubStatsPeriodChanged),
    ).called(1);
  });

  testWidgets('les quatre métriques sont affichées, même à zéro', (
    tester,
  ) async {
    await _pump(
      tester,
      summary: const TripsSummaryModel(activeTrips: 0, kgSold: 0, revenue: 0),
    );

    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text('Kg vendus'), findsOneWidget);
    expect(find.text('Trajets'), findsOneWidget);
    expect(find.text('Envois'), findsOneWidget);
  });

  testWidgets(
    'la tuile Revenus est préfixée de « ≈ » quand le total est converti',
    (tester) async {
      await _pump(
        tester,
        summary: const TripsSummaryModel(
          activeTrips: 1,
          kgSold: 16,
          revenue: 1418.7,
          revenueCurrency: 'EUR',
          revenueConverted: true,
        ),
      );

      expect(find.textContaining('≈ '), findsOneWidget);
    },
  );

  testWidgets(
    'la tuile Revenus est formatée dans la devise annoncée par le backend',
    (tester) async {
      await _pump(
        tester,
        summary: const TripsSummaryModel(
          activeTrips: 1,
          kgSold: 16,
          revenue: 120000,
          revenueCurrency: 'XOF',
          revenueConverted: false,
        ),
      );

      expect(find.textContaining('F CFA'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    },
  );

  testWidgets('la tuile Revenus n\'a pas de « ≈ » sans conversion', (
    tester,
  ) async {
    await _pump(
      tester,
      summary: const TripsSummaryModel(
        activeTrips: 1,
        kgSold: 16.5,
        revenue: 1030,
        revenueCurrency: 'EUR',
        revenueConverted: false,
      ),
    );

    expect(find.textContaining('≈'), findsNothing);
    expect(find.text('16.5 kg'), findsOneWidget);
  });

  testWidgets('taper Revenus ouvre la feuille des revenus', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Revenus'));
    await tester.pumpAndSettle();

    expect(find.byType(RevenueDetailsSheet), findsOneWidget);
    expect(find.text('30 derniers jours'), findsOneWidget);
    verify(
      () => analytics.logEvent(AnalyticsEvents.activitesHubStatsRevenuesOpened),
    ).called(1);
  });

  testWidgets('taper Kg vendus ouvre la feuille des kg', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Kg vendus'));
    await tester.pumpAndSettle();

    expect(find.byType(KgSoldSheet), findsOneWidget);
    verify(
      () => analytics.logEvent(AnalyticsEvents.activitesHubStatsKgSoldOpened),
    ).called(1);
  });

  testWidgets('un trajet choisi dans la feuille Kg ouvre sa fiche', (
    tester,
  ) async {
    await _pump(
      tester,
      kgSold: KgSoldModel(
        period: '30d',
        totalKg: 4,
        parcels: 1,
        trips: [
          KgSoldTripModel(
            tripId: 't1',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            date: DateTime(2026, 9, 12),
            parcels: 1,
            kg: 4,
          ),
        ],
      ),
    );

    await tester.tap(find.text('Kg vendus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kg-trip-t1')));
    await tester.pumpAndSettle();

    expect(visitedUris, contains('/announcements/t1/trip'));
  });

  testWidgets(
    'taper Trajets ouvre Mes trajets filtré sur les terminés, puis recharge le hub au retour',
    (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Trajets'));
      await tester.pumpAndSettle();

      expect(visitedUris, contains('/announcements/trips?filter=completed'));
      verify(
        () => analytics.logEvent(AnalyticsEvents.activitesHubStatsTripsOpened),
      ).called(1);

      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    },
  );

  testWidgets('taper Envois ouvre Mes colis filtré sur les livrés', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Envois'));
    await tester.pumpAndSettle();

    expect(visitedUris, contains('/envois?status=delivered'));
    verify(
      () => analytics.logEvent(AnalyticsEvents.activitesHubStatsParcelsOpened),
    ).called(1);
  });

  testWidgets(
    'sans tripsPublished/parcelsSent (ancien backend) : « - », jamais de tiret cadratin',
    (tester) async {
      await _pump(tester);

      expect(find.text('-'), findsNWidgets(2));
      expect(find.textContaining('—'), findsNothing);
    },
  );

  testWidgets('accord au singulier puis au pluriel', (tester) async {
    await _pump(
      tester,
      summary: const TripsSummaryModel(
        activeTrips: 1,
        kgSold: 1,
        revenue: 10,
        tripsPublished: 1,
        parcelsSent: 4,
      ),
    );

    expect(find.text('1 publié'), findsOneWidget);
    expect(find.text('4 envoyés'), findsOneWidget);
  });

  testWidgets('les tuiles vont deux par deux, à hauteur égale', (tester) async {
    await _pump(tester);

    final revenue = tester.getRect(find.text('Revenus'));
    final kg = tester.getRect(find.text('Kg vendus'));
    final trips = tester.getRect(find.text('Trajets'));
    expect(revenue.top, kg.top);
    expect(trips.top, greaterThan(revenue.bottom));
  });

  testWidgets('en anglais : titre, tuiles et singulier traduits', (
    tester,
  ) async {
    useEnglish();
    await _pump(
      tester,
      summary: const TripsSummaryModel(
        activeTrips: 1,
        kgSold: 1,
        revenue: 10,
        tripsPublished: 1,
        parcelsSent: 1,
      ),
    );

    expect(find.text('My statistics'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Kg sold'), findsOneWidget);
    expect(find.text('1 posted'), findsOneWidget);
    expect(find.text('1 sent'), findsOneWidget);
  });
}
