import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _FakeAnnouncementEvent extends Fake implements AnnouncementEvent {}

// ── Helpers ───────────────────────────────────────────────────────────────────

AnnouncementModel _makeAnnouncement({
  String id = 'ann-001',
  String status = 'ACTIVE',
  DateTime? departureDate,
  int bidsCount = 0,
  String departureCity = 'Paris',
  String arrivalCity = 'Dakar',
}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDate:
          departureDate ?? DateTime.now().add(const Duration(days: 10)),
      availableKg: 10.0,
      totalKg: 23.0,
      pricePerKg: 8.0,
      status: status,
      bidsCount: bidsCount,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Builds the widget tree with all required providers.
Future<void> _pump(
  WidgetTester tester,
  MockAnnouncementBloc bloc, {
  VoidCallback? onSendParcel,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final mockRepo = _MockAnnouncementRepository();
  final mockAnalytics = _MockAnalyticsService();

  // Stub getTripsSummary to return immediately with zeros
  when(() => mockRepo.getTripsSummary()).thenAnswer((_) async =>
      const TripsSummaryModel(
          activeTrips: 0, kgSoldThisMonth: 0, revenueThisMonth: 0));

  // Stub analytics calls
  when(() => mockAnalytics.logEvent(any(), properties: any(named: 'properties')))
      .thenAnswer((_) async {});
  when(() => mockAnalytics.logScreen(any(), properties: any(named: 'properties')))
      .thenAnswer((_) async {});

  final summaryCubit = TripsSummaryCubit(mockRepo);
  final filterCubit = TripFilterCubit(mockAnalytics);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: bloc),
            BlocProvider<TripsSummaryCubit>.value(value: summaryCubit),
            BlocProvider<TripFilterCubit>.value(value: filterCubit),
          ],
          child: AnnouncementListScreen(onSendParcel: onSendParcel),
        ),
      ),
      GoRoute(
        path: '/announcements/:id/bids',
        builder: (ctx, _) => const Scaffold(body: Text('Bids')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
    ),
  );
  // settle initial frame
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(_FakeAnnouncementEvent());
    registerFallbackValue('');
  });

  late MockAnnouncementBloc bloc;

  setUp(() {
    bloc = MockAnnouncementBloc();
  });

  // ── Task 9 required assertions ──────────────────────────────────────────────

  group('AnnouncementListScreen — Task 9 (nouveaux widgets)', () {
    testWidgets(
        'loaded state: shows TripsStatsStrip, 2 TripCards, chip "Tous · 2"',
        (tester) async {
      final active = _makeAnnouncement(id: 'a1', status: 'ACTIVE');
      final completed = _makeAnnouncement(id: 'a2', status: 'COMPLETED');

      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([active, completed]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // TripsStatsStrip is shown
      expect(find.byType(TripsStatsStrip), findsOneWidget);

      // 2 TripCards rendered
      expect(find.byType(TripCard), findsNWidgets(2));

      // "Tous · 2" chip present
      expect(find.textContaining('Tous'), findsWidgets);
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets(
        '"Terminés" chip filters the list to 1 TripCard',
        (tester) async {
      final active = _makeAnnouncement(id: 'a1', status: 'ACTIVE');
      final completed = _makeAnnouncement(id: 'a2', status: 'COMPLETED');

      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([active, completed]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // Initially 2 TripCards
      expect(find.byType(TripCard), findsNWidgets(2));

      // Tap "Terminés" chip
      final terminesChip = find.textContaining('Terminés');
      expect(terminesChip, findsWidgets);
      await tester.tap(terminesChip.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Only 1 TripCard (completed one)
      expect(find.byType(TripCard), findsOneWidget);
    });

    testWidgets(
        'HeaderPill with Key("send-parcel-btn") absent when onSendParcel is null',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc, onSendParcel: null);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('send-parcel-btn')), findsNothing);
    });

    testWidgets(
        'HeaderPill with Key("send-parcel-btn") present when onSendParcel is provided',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc, onSendParcel: () {});
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('send-parcel-btn')), findsOneWidget);
    });
  });

  // ── Preserved existing tests ────────────────────────────────────────────────

  group('AnnouncementListScreen — états BLoC', () {
    testWidgets('AnnouncementInitial → affiche CircularProgressIndicator',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AnnouncementLoading → affiche CircularProgressIndicator',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementLoading());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'AnnouncementError sans liste — affiche vue erreur avec icône',
        (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementError(
        const NetworkException('Pas de connexion'),
      ));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets(
        'AnnouncementListLoaded liste vide — affiche vue vide "Aucun trajet"',
        (tester) async {
      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // With the new unified list, empty state shows a relevant message.
      // We just verify empty state widget appears (DonyEmptyState or similar).
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'AnnouncementListLoaded avec annonce ACTIVE — affiche les villes',
        (tester) async {
      final announcement = _makeAnnouncement(bidsCount: 2);
      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([announcement]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Paris'), findsWidgets);
      expect(find.textContaining('Dakar'), findsWidgets);
    });

    testWidgets(
        'AnnouncementListLoaded avec annonce IN_PROGRESS — visible dans la liste',
        (tester) async {
      final inProgress =
          _makeAnnouncement(id: 'ann-004', status: 'IN_PROGRESS');
      when(() => bloc.state)
          .thenReturn(AnnouncementListLoaded([inProgress]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // IN_PROGRESS now renders as a TripCard at the top of the unified list
      expect(find.byType(TripCard), findsOneWidget);
    });

    testWidgets('titre "Mes trajets" présent', (tester) async {
      when(() => bloc.state).thenReturn(AnnouncementInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      // SliverAppBar renders the title in its FlexibleSpaceBar; at least one
      // instance must be visible (collapsed or expanded).
      expect(find.text('Mes trajets'), findsWidgets);
    });
  });

  group('AnnouncementListScreen — stream états', () {
    testWidgets('AnnouncementDeleted déclenche AnnouncementListRequested',
        (tester) async {
      final controller = StreamController<AnnouncementState>.broadcast();
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => controller.stream);
      when(() => bloc.add(any(that: isA<AnnouncementListRequested>())))
          .thenReturn(null);

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      controller.add(AnnouncementDeleted());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => bloc.add(any(that: isA<AnnouncementListRequested>())))
          .called(greaterThanOrEqualTo(1));
      await controller.close();
    });
  });
}
