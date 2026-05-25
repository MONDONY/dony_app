import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_bloc.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_event.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_state.dart';
import 'package:dony/features/rebooking/data/rebooking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRebookingRepository extends Mock implements RebookingRepository {}

final _fakeBooking = PastBookingItem(
  bidId: 'bid-1',
  travelerId: 'traveler-1',
  travelerName: 'Amadou Diallo',
  travelerBadge: null,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  lastTripDate: DateTime(2026, 4, 1),
  completedTripsWithThisTraveler: 3,
);

void main() {
  late MockRebookingRepository repo;
  late PastBookingsBloc bloc;

  setUp(() {
    repo = MockRebookingRepository();
    bloc = PastBookingsBloc(repo);
  });

  tearDown(() => bloc.close());

  test('initial state is PastBookingsInitial', () {
    expect(bloc.state, isA<PastBookingsInitial>());
  });

  blocTest<PastBookingsBloc, PastBookingsState>(
    'LoadPastBookings emits loading then loaded',
    build: () {
      when(() => repo.getPastBookings()).thenAnswer((_) async => [_fakeBooking]);
      return bloc;
    },
    act: (b) => b.add(const LoadPastBookings()),
    expect: () => [
      isA<PastBookingsLoading>(),
      isA<PastBookingsLoaded>().having((s) => s.bookings.length, 'bookings', 1),
    ],
  );

  blocTest<PastBookingsBloc, PastBookingsState>(
    'RebookTraveler emits rebooking then success',
    build: () {
      when(() => repo.rebook('bid-1'))
          .thenAnswer((_) async => const RebookResult(status: 'REBOOKED', newBidId: 'new-bid-1'));
      return PastBookingsBloc(repo)
        ..emit(PastBookingsLoaded(bookings: [_fakeBooking]));
    },
    act: (b) => b.add(const RebookTraveler('bid-1')),
    expect: () => [
      isA<RebookingInProgress>(),
      isA<RebookSuccess>().having((s) => s.newBidId, 'newBidId', 'new-bid-1'),
    ],
  );

  blocTest<PastBookingsBloc, PastBookingsState>(
    'RebookTraveler emits NoTripAvailable quand voyageur sans départ',
    build: () {
      when(() => repo.rebook('bid-1'))
          .thenAnswer((_) async => const RebookResult(status: 'NO_UPCOMING_TRIP', newBidId: null));
      return PastBookingsBloc(repo)
        ..emit(PastBookingsLoaded(bookings: [_fakeBooking]));
    },
    act: (b) => b.add(const RebookTraveler('bid-1')),
    expect: () => [
      isA<RebookingInProgress>(),
      isA<NoTripAvailable>().having((s) => s.travelerId, 'travelerId', 'traveler-1'),
    ],
  );

  blocTest<PastBookingsBloc, PastBookingsState>(
    'LoadPastBookings emits error quand le repo échoue',
    build: () {
      when(() => repo.getPastBookings()).thenThrow(Exception('boom'));
      return bloc;
    },
    act: (b) => b.add(const LoadPastBookings()),
    expect: () => [
      isA<PastBookingsLoading>(),
      isA<PastBookingsError>(),
    ],
  );

  blocTest<PastBookingsBloc, PastBookingsState>(
    'RebookTraveler emits error quand le repo échoue',
    build: () {
      when(() => repo.rebook('bid-1')).thenThrow(Exception('boom'));
      return PastBookingsBloc(repo)
        ..emit(PastBookingsLoaded(bookings: [_fakeBooking]));
    },
    act: (b) => b.add(const RebookTraveler('bid-1')),
    expect: () => [
      isA<RebookingInProgress>(),
      isA<PastBookingsError>(),
    ],
  );

  blocTest<PastBookingsBloc, PastBookingsState>(
    'SubscribeToTraveler emits error quand le repo échoue',
    build: () {
      when(() => repo.subscribeToTraveler('traveler-1'))
          .thenThrow(Exception('boom'));
      return PastBookingsBloc(repo)
        ..emit(PastBookingsLoaded(bookings: [_fakeBooking]));
    },
    act: (b) => b.add(const SubscribeToTraveler('traveler-1')),
    expect: () => [isA<PastBookingsError>()],
  );

  blocTest<PastBookingsBloc, PastBookingsState>(
    'SubscribeToTraveler calls repo',
    build: () {
      when(() => repo.subscribeToTraveler('traveler-1')).thenAnswer((_) async {});
      return PastBookingsBloc(repo)
        ..emit(PastBookingsLoaded(bookings: [_fakeBooking]));
    },
    act: (b) => b.add(const SubscribeToTraveler('traveler-1')),
    expect: () => [isA<TravelerSubscribed>()],
  );
}
