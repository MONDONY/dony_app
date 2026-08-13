import 'package:dony/features/favorites/bloc/favorite_trips_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FavoriteRepository {}

AnnouncementModel _makeTrip() => AnnouncementModel.fromJson({
  'id': 'trip-1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime.now()
      .add(const Duration(days: 5))
      .toIso8601String(),
  'totalKg': 20.0,
  'availableKg': 15.0,
  'pricePerKg': 8.0,
  'pricingMode': 'KG',
  'status': 'ACTIVE',
  'pendingBidCount': 0,
  'confirmedParcelCount': 0,
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
});

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  // ---------------------------------------------------------------------------
  // load() — non-empty list
  // ---------------------------------------------------------------------------
  test('load() non-empty list → FavoriteTripsLoaded', () async {
    when(() => repo.trips()).thenAnswer((_) async => [_makeTrip()]);

    final cubit = FavoriteTripsCubit(repo);
    await cubit.load();

    expect(cubit.state, isA<FavoriteTripsLoaded>());
    expect((cubit.state as FavoriteTripsLoaded).trips.length, 1);
  });

  // ---------------------------------------------------------------------------
  // load() — empty list
  // ---------------------------------------------------------------------------
  test('load() empty list → FavoriteTripsEmpty', () async {
    when(() => repo.trips()).thenAnswer((_) async => []);

    final cubit = FavoriteTripsCubit(repo);
    await cubit.load();

    expect(cubit.state, isA<FavoriteTripsEmpty>());
  });

  // ---------------------------------------------------------------------------
  // load() — throws
  // ---------------------------------------------------------------------------
  test('load() throws → FavoriteTripsError', () async {
    when(() => repo.trips()).thenThrow(Exception('network error'));

    final cubit = FavoriteTripsCubit(repo);
    await cubit.load();

    expect(cubit.state, isA<FavoriteTripsError>());
  });

  // ---------------------------------------------------------------------------
  // refresh() — delegates to load()
  // ---------------------------------------------------------------------------
  test('refresh() non-empty list → FavoriteTripsLoaded', () async {
    when(() => repo.trips()).thenAnswer((_) async => [_makeTrip()]);

    final cubit = FavoriteTripsCubit(repo);
    await cubit.refresh();

    expect(cubit.state, isA<FavoriteTripsLoaded>());
  });

  // ---------------------------------------------------------------------------
  // state sequence: initial → loading → loaded
  // ---------------------------------------------------------------------------
  test('initial state is FavoriteTripsLoading', () {
    final cubit = FavoriteTripsCubit(repo);
    expect(cubit.state, isA<FavoriteTripsLoading>());
  });

  test('load() ends in Loaded state after successful fetch', () async {
    when(() => repo.trips()).thenAnswer((_) async => [_makeTrip()]);

    final cubit = FavoriteTripsCubit(repo);
    await cubit.load();

    expect(cubit.state, isA<FavoriteTripsLoaded>());
  });
}
