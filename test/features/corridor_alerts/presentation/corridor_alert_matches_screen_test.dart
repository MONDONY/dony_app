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

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

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
    GetIt.I.registerFactoryParam<
      CorridorAlertMatchesCubit,
      String,
      CorridorAlertModel?
    >((_, _) => cubit);
  });

  tearDown(() => GetIt.I.reset());

  Widget pump(AlertDirection direction) => MultiBlocProvider(
    providers: [BlocProvider<AuthBloc>.value(value: authBloc)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: CorridorAlertMatchesScreen(alert: _alert(direction)),
    ),
  );

  testWidgets('package direction loaded → MatchingRequestCard rendered', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      CorridorAlertMatchesState(
        status: CorridorAlertMatchesStatus.loaded,
        result: CorridorAlertMatches(
          direction: AlertDirection.travelerWantsPackages,
          packages: [_fakePackage()],
        ),
      ),
    );
    await tester.pumpWidget(pump(AlertDirection.travelerWantsPackages));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MatchingRequestCard), findsOneWidget);
  });

  testWidgets(
    'alertId seul (push) : titre et bouton Modifier viennent de l\'alerte chargée',
    (tester) async {
      when(() => cubit.state).thenReturn(
        CorridorAlertMatchesState(
          status: CorridorAlertMatchesStatus.loaded,
          alert: _alert(AlertDirection.senderWantsTrips),
          result: CorridorAlertMatches(
            direction: AlertDirection.senderWantsTrips,
            trips: [_fakeTrip()],
          ),
        ),
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [BlocProvider<AuthBloc>.value(value: authBloc)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CorridorAlertMatchesScreen(alertId: 'alert-1'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Paris → Dakar'), findsWidgets);
      expect(find.byTooltip('Modifier l\'alerte'), findsOneWidget);
      expect(find.byType(TripMatchCard), findsOneWidget);
    },
  );

  testWidgets('alertId seul, alerte pas encore chargée : titre neutre', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const CorridorAlertMatchesState(
        status: CorridorAlertMatchesStatus.loading,
      ),
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider<AuthBloc>.value(value: authBloc)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CorridorAlertMatchesScreen(alertId: 'alert-1'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mes alertes'), findsOneWidget);
    expect(find.byTooltip('Modifier l\'alerte'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('trip direction loaded → TripMatchCard rendered', (tester) async {
    when(() => cubit.state).thenReturn(
      CorridorAlertMatchesState(
        status: CorridorAlertMatchesStatus.loaded,
        result: CorridorAlertMatches(
          direction: AlertDirection.senderWantsTrips,
          trips: [_fakeTrip()],
        ),
      ),
    );
    await tester.pumpWidget(pump(AlertDirection.senderWantsTrips));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TripMatchCard), findsOneWidget);
  });

  testWidgets('nouveautés : bandeau résumé, section Nouveaux puis Déjà vus', (
    tester,
  ) async {
    final seenAt = DateTime(2026, 9, 1, 8);
    final fresh = TripMatchModel(
      announcementId: 'ann-new',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 9, 18),
      travelerId: 't-2',
      travelerName: 'Moussa D.',
      travelerInitials: 'MD',
      travelerRating: 4.9,
      availableKg: 12.0,
      publishedAt: DateTime(2026, 9, 3),
    );
    final old = TripMatchModel(
      announcementId: 'ann-old',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 9, 16),
      travelerId: 't-3',
      travelerName: 'Ibrahima N.',
      travelerInitials: 'IN',
      travelerRating: 4.2,
      availableKg: 8.0,
      publishedAt: DateTime(2026, 8, 20),
    );
    when(() => cubit.state).thenReturn(
      CorridorAlertMatchesState(
        status: CorridorAlertMatchesStatus.loaded,
        alert: _alert(AlertDirection.senderWantsTrips),
        thresholdKnown: true,
        seenThreshold: seenAt,
        result: CorridorAlertMatches(
          direction: AlertDirection.senderWantsTrips,
          trips: [old, fresh],
        ),
      ),
    );
    await tester.pumpWidget(pump(AlertDirection.senderWantsTrips));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('alert-summary-banner')), findsOneWidget);
    expect(find.text('Alerte active'), findsOneWidget);
    expect(find.text('Nouveaux · 1 trajet'), findsOneWidget);
    expect(find.text('Déjà vus · 1 trajet'), findsOneWidget);
    expect(find.byType(TripMatchCard), findsNWidgets(2));

    // Le nouveau vient en premier, même s'il était second dans la réponse.
    final newY = tester.getTopLeft(find.text('Moussa D.')).dy;
    final oldY = tester.getTopLeft(find.text('Ibrahima N.')).dy;
    expect(newY, lessThan(oldY));
  });

  testWidgets('sans nouveauté : un seul compteur, pas de section', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      CorridorAlertMatchesState(
        status: CorridorAlertMatchesStatus.loaded,
        alert: _alert(AlertDirection.senderWantsTrips),
        thresholdKnown: true,
        seenThreshold: DateTime(2026, 9, 4),
        result: CorridorAlertMatches(
          direction: AlertDirection.senderWantsTrips,
          trips: [_fakeTrip()],
        ),
      ),
    );
    await tester.pumpWidget(pump(AlertDirection.senderWantsTrips));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1 trajet'), findsOneWidget);
    expect(find.textContaining('Nouveaux'), findsNothing);
    expect(find.textContaining('Déjà vus'), findsNothing);
  });

  testWidgets('alerte en pause : le bandeau le dit', (tester) async {
    when(() => cubit.state).thenReturn(
      CorridorAlertMatchesState(
        status: CorridorAlertMatchesStatus.empty,
        alert: _alert(
          AlertDirection.travelerWantsPackages,
        ).copyWith(active: false),
      ),
    );
    await tester.pumpWidget(pump(AlertDirection.travelerWantsPackages));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Alerte en pause'), findsOneWidget);
    expect(find.textContaining('Aucun colis'), findsWidgets);
  });

  testWidgets('trip direction empty → Aucun trajet copy', (tester) async {
    when(() => cubit.state).thenReturn(
      const CorridorAlertMatchesState(status: CorridorAlertMatchesStatus.empty),
    );
    await tester.pumpWidget(pump(AlertDirection.senderWantsTrips));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Aucun trajet'), findsWidgets);
  });

  testWidgets('package direction empty → Aucun colis copy', (tester) async {
    when(() => cubit.state).thenReturn(
      const CorridorAlertMatchesState(status: CorridorAlertMatchesStatus.empty),
    );
    await tester.pumpWidget(pump(AlertDirection.travelerWantsPackages));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Aucun colis'), findsWidgets);
  });

  testWidgets(
    'trip direction loaded → tapping TripMatchCard navigates to /traveler/ann-1',
    (tester) async {
      when(() => cubit.state).thenReturn(
        CorridorAlertMatchesState(
          status: CorridorAlertMatchesStatus.loaded,
          result: CorridorAlertMatches(
            direction: AlertDirection.senderWantsTrips,
            trips: [_fakeTrip()],
          ),
        ),
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/matches',
            builder: (context, state) => MultiBlocProvider(
              providers: [BlocProvider<AuthBloc>.value(value: authBloc)],
              child: CorridorAlertMatchesScreen(
                alert: _alert(AlertDirection.senderWantsTrips),
              ),
            ),
          ),
          GoRoute(
            path: '/traveler/:announcementId',
            builder: (context, state) =>
                const Scaffold(body: Text('traveler-detail')),
          ),
        ],
        initialLocation: '/matches',
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TripMatchCard), findsOneWidget);

      await tester.tap(find.byType(TripMatchCard));
      await tester.pumpAndSettle();

      expect(find.text('traveler-detail'), findsOneWidget);
    },
  );
}
