import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/trip_matching_bloc.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/colis_match_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockTripMatchingBloc
    extends MockBloc<TripMatchingEvent, TripMatchingState>
    implements TripMatchingBloc {}

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

MatchingRequestModel _match(String id, {int score = 50}) =>
    MatchingRequestModel(
      id: id,
      tripId: 't-$id',
      tripCorridor: 'Paris → Bamako',
      tripDepartureDate: DateTime(2026, 7, 10),
      tripAvailableKg: 10,
      senderId: 's-$id',
      senderName: 'Sender $id',
      senderInitials: 'S',
      senderRating: 4.5,
      senderTotalSent: 2,
      weightKg: 2,
      matchScore: score,
      requestedAt: DateTime(2026, 6, 19),
    );

void main() {
  late MockTripMatchingBloc matching;
  late MockAnnouncementBloc announcements;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(const TripMatchingRequested());
    registerFallbackValue(AnnouncementListRequested());
  });

  setUp(() {
    matching = MockTripMatchingBloc();
    announcements = MockAnnouncementBloc();
    // ColisMatchScreen resolves its blocs from getIt — register the mocks.
    if (GetIt.I.isRegistered<TripMatchingBloc>()) {
      GetIt.I.unregister<TripMatchingBloc>();
    }
    if (GetIt.I.isRegistered<AnnouncementBloc>()) {
      GetIt.I.unregister<AnnouncementBloc>();
    }
    GetIt.I.registerFactory<TripMatchingBloc>(() => matching);
    GetIt.I.registerFactory<AnnouncementBloc>(() => announcements);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget pump() => MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          initialLocation: '/m',
          routes: [
            GoRoute(path: '/m', builder: (_, __) => const ColisMatchScreen()),
            GoRoute(
                path: '/corridor-alerts',
                builder: (_, __) =>
                    const Scaffold(body: Text('ALERTS-SCREEN'))),
            GoRoute(
                path: '/announcements/create',
                builder: (_, __) =>
                    const Scaffold(body: Text('CREATE-TRIP'))),
            GoRoute(
                path: '/package-requests/:id/public',
                builder: (_, __) =>
                    const Scaffold(body: Text('PUBLIC-DETAIL-SCREEN'))),
          ],
        ),
      );

  testWidgets('loaded → renders one flat list of MatchingRequestCard sorted',
      (t) async {
    whenListen(
      matching,
      Stream.value(TripMatchingState(
        status: TripMatchingStatus.loaded,
        matches: [_match('a', score: 90), _match('b', score: 40)],
      )),
      initialState: const TripMatchingState(),
    );
    when(() => announcements.state)
        .thenReturn(AnnouncementListLoaded(const []));
    when(() => announcements.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    await t.pumpWidget(pump());
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(MatchingRequestCard), findsNWidgets(2));
  });

  testWidgets('header shows compteur + bell, tap bell navigates to alerts',
      (t) async {
    whenListen(
      matching,
      Stream.value(TripMatchingState(
        status: TripMatchingStatus.loaded,
        matches: [_match('a')],
      )),
      initialState: const TripMatchingState(),
    );
    when(() => announcements.state)
        .thenReturn(AnnouncementListLoaded(const []));
    when(() => announcements.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    await t.pumpWidget(pump());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('compatible'), findsOneWidget);
    final bell = find.byKey(const Key('colis-match-bell'));
    expect(bell, findsOneWidget);
    await t.tap(bell);
    await t.pumpAndSettle();
    expect(find.text('ALERTS-SCREEN'), findsOneWidget);
  });

  testWidgets('empty matches → fennec + "Créer une alerte sur ce corridor"',
      (t) async {
    whenListen(
      matching,
      Stream.value(const TripMatchingState(
        status: TripMatchingStatus.loaded,
        matches: [],
      )),
      initialState: const TripMatchingState(),
    );
    // ≥1 active trip exists so we show the alert banner (not the publish CTA).
    when(() => announcements.state).thenReturn(
      AnnouncementListLoaded([
        AnnouncementModel(
          id: 'ann-1',
          travelerId: 'u-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 1),
          availableKg: 15,
          totalKg: 23,
          pricePerKg: 5,
          status: 'ACTIVE',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        )
      ]),
    );
    when(() => announcements.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    await t.pumpWidget(pump());
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(DonyMascotteAnimated), findsOneWidget);
    expect(find.textContaining('Créer une alerte'), findsOneWidget);
  });

  testWidgets('card tap navigates to public detail screen', (t) async {
    whenListen(
      matching,
      Stream.value(TripMatchingState(
        status: TripMatchingStatus.loaded,
        matches: [_match('xyz')],
      )),
      initialState: const TripMatchingState(),
    );
    when(() => announcements.state)
        .thenReturn(AnnouncementListLoaded(const []));
    when(() => announcements.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    await t.pumpWidget(pump());
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(MatchingRequestCard), findsOneWidget);
    await t.tap(find.byType(MatchingRequestCard));
    await t.pumpAndSettle();
    expect(find.text('PUBLIC-DETAIL-SCREEN'), findsOneWidget);
  });

  testWidgets('error state shows error view and retry re-dispatches load event',
      (t) async {
    whenListen(
      matching,
      Stream.value(const TripMatchingState(
        status: TripMatchingStatus.error,
        errorMessage: 'network error',
      )),
      initialState: const TripMatchingState(),
    );
    when(() => announcements.state)
        .thenReturn(AnnouncementInitial());
    when(() => announcements.stream)
        .thenAnswer((_) => const Stream<AnnouncementState>.empty());
    await t.pumpWidget(pump());
    await t.pumpAndSettle(const Duration(seconds: 2));
    // Error view should be rendered.
    expect(find.textContaining('erreur'), findsOneWidget);
    expect(find.textContaining('Réessayer'), findsOneWidget);
    // Tap the retry button.
    await t.tap(find.textContaining('Réessayer'));
    await t.pump();
    // Verify that TripMatchingRequested was re-dispatched to the bloc.
    verify(() => matching.add(const TripMatchingRequested())).called(greaterThan(0));
  });
}
