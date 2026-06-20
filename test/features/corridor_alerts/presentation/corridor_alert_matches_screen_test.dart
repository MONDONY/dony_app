import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_matches_cubit.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_matches.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_matches_screen.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/trip_match_card.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchesCubit extends MockCubit<CorridorAlertMatchesState>
    implements CorridorAlertMatchesCubit {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

CorridorAlertModel _alert(AlertDirection direction) => CorridorAlertModel(
      id: 'alert-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      active: true,
      matchCount: 1,
      direction: direction,
      createdAt: DateTime(2026, 6, 20),
    );

MatchingRequestModel _fakePackage() => MatchingRequestModel(
      id: 'p-1',
      senderId: 'sender-1',
      senderName: 'Jean D.',
      senderInitials: 'JD',
      senderRating: 4.5,
      senderTotalSent: 10,
      weightKg: 5.0,
      budgetPerKg: 10.0,
      matchScore: 85,
      requestedAt: DateTime(2026, 6, 20),
    );

TripMatchModel _fakeTrip() => TripMatchModel(
      announcementId: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 7, 10),
      travelerId: 't-1',
      travelerName: 'Awa S.',
      travelerInitials: 'AS',
      travelerRating: 4.7,
      availableKg: 12.0,
      pricePerKg: 9.5,
    );

void main() {
  late MockMatchesCubit cubit;
  late MockAuthBloc authBloc;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
  });

  setUp(() {
    cubit = MockMatchesCubit();
    authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthInitial());
    // Stub load() so the screen's BlocProvider create clause doesn't throw.
    when(() => cubit.load()).thenAnswer((_) async {});
    // GetIt: register the cubit factory param so the screen can build it.
    GetIt.I.registerFactoryParam<CorridorAlertMatchesCubit, String,
        AlertDirection>(
      (_, __) => cubit,
    );
  });

  tearDown(() => GetIt.I.reset());

  Widget pump(AlertDirection direction) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: CorridorAlertMatchesScreen(alert: _alert(direction)),
        ),
      );

  testWidgets('package direction loaded → MatchingRequestCard rendered',
      (tester) async {
    when(() => cubit.state).thenReturn(CorridorAlertMatchesState(
      status: CorridorAlertMatchesStatus.loaded,
      result: CorridorAlertMatches(
        direction: AlertDirection.travelerWantsPackages,
        packages: [_fakePackage()],
      ),
    ));
    await tester.pumpWidget(pump(AlertDirection.travelerWantsPackages));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MatchingRequestCard), findsOneWidget);
  });

  testWidgets('trip direction loaded → TripMatchCard rendered', (tester) async {
    when(() => cubit.state).thenReturn(CorridorAlertMatchesState(
      status: CorridorAlertMatchesStatus.loaded,
      result: CorridorAlertMatches(
        direction: AlertDirection.senderWantsTrips,
        trips: [_fakeTrip()],
      ),
    ));
    await tester.pumpWidget(pump(AlertDirection.senderWantsTrips));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TripMatchCard), findsOneWidget);
  });

  testWidgets('trip direction empty → Aucun trajet copy', (tester) async {
    when(() => cubit.state).thenReturn(const CorridorAlertMatchesState(
      status: CorridorAlertMatchesStatus.empty,
    ));
    await tester.pumpWidget(pump(AlertDirection.senderWantsTrips));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Aucun trajet'), findsWidgets);
  });

  testWidgets('package direction empty → Aucun colis copy', (tester) async {
    when(() => cubit.state).thenReturn(const CorridorAlertMatchesState(
      status: CorridorAlertMatchesStatus.empty,
    ));
    await tester.pumpWidget(pump(AlertDirection.travelerWantsPackages));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Aucun colis'), findsWidgets);
  });

  testWidgets(
      'trip direction loaded → tapping TripMatchCard navigates to /traveler/ann-1',
      (tester) async {
    when(() => cubit.state).thenReturn(CorridorAlertMatchesState(
      status: CorridorAlertMatchesStatus.loaded,
      result: CorridorAlertMatches(
        direction: AlertDirection.senderWantsTrips,
        trips: [_fakeTrip()],
      ),
    ));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/matches',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: CorridorAlertMatchesScreen(
                alert: _alert(AlertDirection.senderWantsTrips)),
          ),
        ),
        GoRoute(
          path: '/traveler/:announcementId',
          builder: (context, state) => const Scaffold(
            body: Text('traveler-detail'),
          ),
        ),
      ],
      initialLocation: '/matches',
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(TripMatchCard), findsOneWidget);

    await tester.tap(find.byType(TripMatchCard));
    await tester.pumpAndSettle();

    expect(find.text('traveler-detail'), findsOneWidget);
  });
}
