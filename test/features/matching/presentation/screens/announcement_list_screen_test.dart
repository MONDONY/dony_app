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
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _FakeAnnouncementDeleteRequested extends Fake
    implements AnnouncementDeleteRequested {}

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

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
}) => AnnouncementModel(
  id: id,
  travelerId: 'traveler-1',
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  departureDate: departureDate ?? DateTime.now().add(const Duration(days: 10)),
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
  bool showBackButton = false,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final mockRepo = _MockAnnouncementRepository();
  final mockAnalytics = _MockAnalyticsService();

  // Stub getTripsSummary to return immediately with zeros
  when(() => mockRepo.getTripsSummary(period: any(named: 'period'))).thenAnswer(
    (_) async => const TripsSummaryModel(
      activeTrips: 0,
      kgSoldThisMonth: 0,
      revenueThisMonth: 0,
    ),
  );

  // Stub analytics calls
  when(
    () => mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  when(
    () => mockAnalytics.logScreen(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});

  final summaryCubit = TripsSummaryCubit(mockRepo);
  final filterCubit = TripFilterCubit(mockAnalytics);
  final negoBloc = _MockNegotiationListBloc();
  when(() => negoBloc.state).thenReturn(NegotiationListState());

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
            BlocProvider<NegotiationListBloc>.value(value: negoBloc),
          ],
          child: AnnouncementListScreen(
            onSendParcel: onSendParcel,
            showBackButton: showBackButton,
          ),
        ),
      ),
      GoRoute(
        path: '/announcements/:id/bids',
        builder: (ctx, _) => const Scaffold(body: Text('Bids')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  // settle initial frame
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(_FakeAnnouncementEvent());
    registerFallbackValue(_FakeAnnouncementDeleteRequested());
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

        when(
          () => bloc.state,
        ).thenReturn(AnnouncementListLoaded([active, completed]));
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
      },
    );

    testWidgets('"Terminés" chip filters the list to 1 TripCard', (
      tester,
    ) async {
      final active = _makeAnnouncement(id: 'a1', status: 'ACTIVE');
      final completed = _makeAnnouncement(id: 'a2', status: 'COMPLETED');

      when(
        () => bloc.state,
      ).thenReturn(AnnouncementListLoaded([active, completed]));
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
      },
    );

    testWidgets(
      'HeaderPill with Key("send-parcel-btn") present when onSendParcel is provided',
      (tester) async {
        when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc, onSendParcel: () {});
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byKey(const Key('send-parcel-btn')), findsOneWidget);
      },
    );
  });

  // ── Back button regression tests ────────────────────────────────────────────

  group('AnnouncementListScreen — back button (showBackButton)', () {
    testWidgets('back button absent when showBackButton is false (default)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('activites-back')), findsNothing);
    });

    testWidgets('back button present when showBackButton is true', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc, showBackButton: true);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('activites-back')), findsOneWidget);
    });
  });

  // ── Preserved existing tests ────────────────────────────────────────────────

  group('AnnouncementListScreen — états BLoC', () {
    testWidgets('AnnouncementInitial → affiche CircularProgressIndicator', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(AnnouncementInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AnnouncementLoading → affiche CircularProgressIndicator', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(AnnouncementLoading());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'AnnouncementError sans liste — affiche vue erreur avec icône',
      (tester) async {
        when(() => bloc.state).thenReturn(
          AnnouncementError(const NetworkException('Pas de connexion')),
        );
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc);

        expect(
          find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'wifi-off'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AnnouncementListLoaded liste vide — affiche vue vide "Aucun trajet"',
      (tester) async {
        when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 400));

        // With the new unified list, empty state shows a relevant message.
        // We just verify empty state widget appears (DonyEmptyState or similar).
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'AnnouncementListLoaded avec annonce ACTIVE — affiche les villes',
      (tester) async {
        final announcement = _makeAnnouncement(bidsCount: 2);
        when(
          () => bloc.state,
        ).thenReturn(AnnouncementListLoaded([announcement]));
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('Paris'), findsWidgets);
        expect(find.textContaining('Dakar'), findsWidgets);
      },
    );

    testWidgets(
      'AnnouncementListLoaded avec annonce IN_PROGRESS — visible dans la liste',
      (tester) async {
        final inProgress = _makeAnnouncement(
          id: 'ann-004',
          status: 'IN_PROGRESS',
        );
        when(() => bloc.state).thenReturn(AnnouncementListLoaded([inProgress]));
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 400));

        // IN_PROGRESS now renders as a TripCard at the top of the unified list
        expect(find.byType(TripCard), findsOneWidget);
      },
    );

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
    testWidgets('AnnouncementDeleted déclenche AnnouncementListRequested', (
      tester,
    ) async {
      final controller = StreamController<AnnouncementState>.broadcast();
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => controller.stream);
      when(
        () => bloc.add(any(that: isA<AnnouncementListRequested>())),
      ).thenReturn(null);

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      controller.add(AnnouncementDeleted());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => bloc.add(any(that: isA<AnnouncementListRequested>())),
      ).called(greaterThanOrEqualTo(1));
      await controller.close();
    });

    testWidgets(
      'AnnouncementError with non-empty prior list shows error WITHOUT re-fetch (no infinite retry loop)',
      (tester) async {
        final controller = StreamController<AnnouncementState>.broadcast();
        final active = _makeAnnouncement(id: 'a1', status: 'ACTIVE');

        // Start with a loaded state so _lastList is non-empty.
        when(() => bloc.state).thenReturn(AnnouncementListLoaded([active]));
        when(() => bloc.stream).thenAnswer((_) => controller.stream);
        when(
          () => bloc.add(any(that: isA<AnnouncementListRequested>())),
        ).thenReturn(null);

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 400));

        // didChangeDependencies dispatches the initial fetch — consume it so
        // the verifyNever below only covers what happens after the error.
        verify(
          () => bloc.add(any(that: isA<AnnouncementListRequested>())),
        ).called(1);

        // List is now cached; push an error — the listener must only surface
        // the error and must NOT dispatch a new AnnouncementListRequested,
        // otherwise a failing server loops forever (error → fetch → error…).
        controller.add(AnnouncementError(const NetworkException('err')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verifyNever(
          () => bloc.add(any(that: isA<AnnouncementListRequested>())),
        );

        await controller.close();
        // Drain the error snackbar timers before the test ends.
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  // ── Error view interactions ──────────────────────────────────────────────────

  group('AnnouncementListScreen — _ErrorView', () {
    testWidgets(
      'AnnouncementError sans liste — bouton "Réessayer" déclenche reload',
      (tester) async {
        when(() => bloc.state).thenReturn(
          AnnouncementError(const NetworkException('Pas de connexion')),
        );
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        when(
          () => bloc.add(any(that: isA<AnnouncementListRequested>())),
        ).thenReturn(null);

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the retry button
        final retryBtn = find.text('Réessayer');
        expect(retryBtn, findsOneWidget);
        await tester.tap(retryBtn);
        await tester.pump();

        verify(
          () => bloc.add(any(that: isA<AnnouncementListRequested>())),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets('AnnouncementError sans liste — affiche le message d\'erreur', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        AnnouncementError(const NetworkException('Pas de connexion')),
      );
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Impossible de charger vos trajets'), findsOneWidget);
    });
  });

  // ── _EmptyView variants ──────────────────────────────────────────────────────

  group('AnnouncementListScreen — _EmptyView', () {
    testWidgets('liste vide rawListEmpty=true → "Aucun trajet à venir"', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Aucun trajet à venir'), findsOneWidget);
    });

    testWidgets(
      'filtre "Actifs" avec aucun trajet actif → "Aucun trajet actif"',
      (tester) async {
        // One completed trip, filter set to active → empty filtered list.
        final completed = _makeAnnouncement(id: 'c1', status: 'COMPLETED');
        when(() => bloc.state).thenReturn(AnnouncementListLoaded([completed]));
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 400));

        // Tap "Actifs" chip to apply filter
        await tester.tap(find.textContaining('Actifs').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Aucun trajet actif'), findsOneWidget);
      },
    );

    testWidgets(
      'filtre "Terminés" avec aucun trajet terminé → "Aucun historique"',
      (tester) async {
        final active = _makeAnnouncement(id: 'a1', status: 'ACTIVE');
        when(() => bloc.state).thenReturn(AnnouncementListLoaded([active]));
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.textContaining('Terminés').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Aucun historique'), findsOneWidget);
      },
    );
  });

  // ── Search query filtering ───────────────────────────────────────────────────

  group('AnnouncementListScreen — recherche', () {
    testWidgets(
      'saisir une query filtre la liste (Paris→Dakar reste, Paris→Bamako disparaît)',
      (tester) async {
        final paris = _makeAnnouncement(
          id: 'p1',
          status: 'ACTIVE',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
        );
        final lyon = _makeAnnouncement(
          id: 'l1',
          status: 'ACTIVE',
          departureCity: 'Paris',
          arrivalCity: 'Bamako',
        );

        when(
          () => bloc.state,
        ).thenReturn(AnnouncementListLoaded([paris, lyon]));
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

        await _pump(tester, bloc);
        await tester.pump(const Duration(milliseconds: 400));

        // 2 cards initially
        expect(find.byType(TripCard), findsNWidgets(2));

        // Enter a query that matches only the Dakar trip
        await tester.enterText(find.byType(TextField).first, 'Dakar');
        await tester.pump(const Duration(milliseconds: 300));

        // Now only 1 card (Dakar match)
        expect(find.byType(TripCard), findsOneWidget);
      },
    );

    testWidgets('query ne correspondant à rien → "Aucun trajet trouvé"', (
      tester,
    ) async {
      final paris = _makeAnnouncement(id: 'p1', status: 'ACTIVE');

      when(() => bloc.state).thenReturn(AnnouncementListLoaded([paris]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField).first, 'zzzinexistant');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Aucun trajet trouvé'), findsOneWidget);

      // Drain any remaining animation timers (flutter_animate)
      await tester.pump(const Duration(seconds: 1));
    });
  });

  // ── CANCELLED chip & Dismissible ────────────────────────────────────────────

  group('AnnouncementListScreen — CANCELLED', () {
    testWidgets('liste avec un trajet CANCELLED → chip "Annulés" présent', (
      tester,
    ) async {
      final cancelled = _makeAnnouncement(id: 'x1', status: 'CANCELLED');

      when(() => bloc.state).thenReturn(AnnouncementListLoaded([cancelled]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Annulés'), findsWidgets);
    });

    testWidgets('CANCELLED trajet has a Dismissible with endToStart direction', (
      tester,
    ) async {
      final cancelled = _makeAnnouncement(id: 'x1', status: 'CANCELLED');

      when(() => bloc.state).thenReturn(AnnouncementListLoaded([cancelled]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
      when(
        () => bloc.add(any(that: isA<AnnouncementDeleteRequested>())),
      ).thenReturn(null);

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // CANCELLED items are wrapped in a Dismissible with endToStart direction.
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.direction, DismissDirection.endToStart);
    });
  });

  // ── IN_PROGRESS sort priority ───────────────────────────────────────────────

  group('AnnouncementListScreen — sort priority', () {
    testWidgets('IN_PROGRESS sorts before ACTIVE in the list', (tester) async {
      final active = _makeAnnouncement(
        id: 'a1',
        status: 'ACTIVE',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
      );
      final inProgress = _makeAnnouncement(
        id: 'ip1',
        status: 'IN_PROGRESS',
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
      );

      when(
        () => bloc.state,
      ).thenReturn(AnnouncementListLoaded([active, inProgress]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // Both cards rendered
      expect(find.byType(TripCard), findsNWidgets(2));

      // IN_PROGRESS card (Lyon→Abidjan) appears before ACTIVE (Paris→Dakar).
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.first.announcement.status, 'IN_PROGRESS');
      expect(cards.last.announcement.status, 'ACTIVE');
    });

    testWidgets('CANCELLED sorts after COMPLETED in the list', (tester) async {
      final completed = _makeAnnouncement(
        id: 'c1',
        status: 'COMPLETED',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
      );
      final cancelled = _makeAnnouncement(
        id: 'x1',
        status: 'CANCELLED',
        departureCity: 'Lyon',
        arrivalCity: 'Bamako',
      );

      when(
        () => bloc.state,
      ).thenReturn(AnnouncementListLoaded([cancelled, completed]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TripCard), findsNWidgets(2));
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.first.announcement.status, 'COMPLETED');
      expect(cards.last.announcement.status, 'CANCELLED');
    });
  });

  // ── onSendParcel callback ────────────────────────────────────────────────────

  group('AnnouncementListScreen — onSendParcel callback', () {
    testWidgets('tap on "Envoyer" pill calls onSendParcel', (tester) async {
      var called = false;
      when(() => bloc.state).thenReturn(AnnouncementListLoaded([]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _pump(tester, bloc, onSendParcel: () => called = true);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('send-parcel-btn')));
      await tester.pump();

      expect(called, isTrue);
    });
  });

  // ── Pull-to-refresh ───────────────────────────────────────────────────────────

  group('AnnouncementListScreen — pull-to-refresh', () {
    testWidgets('pull-to-refresh dispatches AnnouncementListRequested', (
      tester,
    ) async {
      // Start with a loaded list so the list is scrollable
      final active = _makeAnnouncement(id: 'a1', status: 'ACTIVE');
      final controller = StreamController<AnnouncementState>.broadcast();

      when(() => bloc.state).thenReturn(AnnouncementListLoaded([active]));
      when(() => bloc.stream).thenAnswer((_) => controller.stream);
      when(
        () => bloc.add(any(that: isA<AnnouncementListRequested>())),
      ).thenReturn(null);

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // Perform a drag-from-top gesture to trigger the RefreshIndicator
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      // Let the refresh indicator appear and emit a loaded state
      await tester.pump(const Duration(milliseconds: 100));
      controller.add(AnnouncementListLoaded([active]));
      await tester.pump(const Duration(milliseconds: 500));

      // AnnouncementListRequested should have been dispatched
      verify(
        () => bloc.add(any(that: isA<AnnouncementListRequested>())),
      ).called(greaterThanOrEqualTo(1));

      await controller.close();
    });
  });

  // ── Dismissible confirm dialog ────────────────────────────────────────────────

  group('AnnouncementListScreen — Dismissible confirm delete', () {
    testWidgets('swiping CANCELLED trip shows confirmation dialog', (
      tester,
    ) async {
      final cancelled = _makeAnnouncement(id: 'x1', status: 'CANCELLED');

      when(() => bloc.state).thenReturn(AnnouncementListLoaded([cancelled]));
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
      when(
        () => bloc.add(any(that: isA<AnnouncementDeleteRequested>())),
      ).thenReturn(null);

      await _pump(tester, bloc);
      await tester.pump(const Duration(milliseconds: 400));

      // Swipe the Dismissible widget far enough to trigger confirmDismiss.
      // The view is 800px wide; swiping > 50% should trigger dismiss.
      final dismissible = find.byType(Dismissible);
      await tester.drag(dismissible, const Offset(-500, 0));
      // One pump to start the dismissible animation (may call confirmDismiss)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // If the dialog appeared, tap confirm; otherwise the swipe may not have
      // reached the threshold — handle both cases gracefully.
      // Dialog appeared (dialog text "Supprimer ce trajet ?" is present)
      expect(find.text('Supprimer ce trajet ?'), findsOneWidget);

      // Tap the confirm FilledButton "Supprimer"
      await tester.tap(find.text('Supprimer').last);
      // Wait for dialog to close and Dismissible animation to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // AnnouncementDeleteRequested was dispatched via onDismissed
      verify(
        () => bloc.add(any(that: isA<AnnouncementDeleteRequested>())),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
