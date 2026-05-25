import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_bloc.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_event.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_state.dart';
import 'package:dony/features/rebooking/data/rebooking_repository.dart';
import 'package:dony/features/rebooking/presentation/past_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockPastBookingsBloc extends MockBloc<PastBookingsEvent, PastBookingsState>
    implements PastBookingsBloc {}

final _item = PastBookingItem(
  bidId: 'bid-1',
  travelerId: 'traveler-1',
  travelerName: 'Fatoumata Koné',
  travelerBadge: null,
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
  lastTripDate: DateTime(2026, 3, 15),
  completedTripsWithThisTraveler: 2,
);

void main() {
  late MockPastBookingsBloc bloc;

  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => bloc = MockPastBookingsBloc());

  Widget pumpable() => MaterialApp(
        home: BlocProvider<PastBookingsBloc>.value(
          value: bloc,
          child: const PastBookingsScreen(),
        ),
      );

  Widget routerPumpable() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<PastBookingsBloc>.value(
            value: bloc,
            child: const PastBookingsScreen(),
          ),
        ),
        GoRoute(
          path: '/profile/shipments/history',
          builder: (_, __) => const Scaffold(body: Text('HISTORY')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('affiche les cartes de réservation quand loaded', (tester) async {
    when(() => bloc.state).thenReturn(PastBookingsLoaded(bookings: [_item]));

    await tester.pumpWidget(pumpable());

    expect(find.text('Fatoumata Koné'), findsOneWidget);
    expect(find.text('Paris → Bamako'), findsOneWidget);
  });

  testWidgets('bottom sheet "Me notifier" apparaît quand NoTripAvailable',
      (tester) async {
    whenListen(
      bloc,
      Stream.fromIterable([
        const PastBookingsLoaded(bookings: []),
        const NoTripAvailable('traveler-1'),
      ]),
      initialState: const PastBookingsLoaded(bookings: []),
    );

    await tester.pumpWidget(pumpable());
    await tester.pumpAndSettle();

    expect(find.text('Aucun voyage disponible'), findsOneWidget);
    expect(find.text('Me notifier à la prochaine annonce'), findsOneWidget);
  });

  testWidgets('RebookingInProgress affiche le loader de vérification',
      (tester) async {
    when(() => bloc.state).thenReturn(const RebookingInProgress());

    await tester.pumpWidget(pumpable());

    expect(find.text('Vérification de la disponibilité…'), findsOneWidget);
  });

  testWidgets('RebookSuccess redirige vers l\'historique', (tester) async {
    whenListen(
      bloc,
      Stream.fromIterable([
        const PastBookingsLoaded(bookings: []),
        const RebookSuccess('new-bid-1'),
      ]),
      initialState: const PastBookingsLoaded(bookings: []),
    );

    await tester.pumpWidget(routerPumpable());
    await tester.pumpAndSettle();

    expect(find.text('HISTORY'), findsOneWidget);
  });
}
