import 'package:dony/features/favorites/bloc/favorite_requests_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FavoriteRepository {}

PackageRequestSearchItem _makeItem() => PackageRequestSearchItem(
      id: 'req-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2025, 6, 1),
      dateToleranceDays: 3,
      weightKg: 5.0,
      parcelSize: ParcelSize.medium,
      sender: const SenderPublicProfile(
        id: 'sender-1',
        displayName: 'Mamadou Diallo',
        averageRating: 4.8,
        totalRatings: 10,
        kycVerified: true,
      ),
    );

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  // ---------------------------------------------------------------------------
  // load() — non-empty list
  // ---------------------------------------------------------------------------
  test('load() non-empty list → FavoriteRequestsLoaded', () async {
    when(() => repo.packageRequests()).thenAnswer((_) async => [_makeItem()]);

    final cubit = FavoriteRequestsCubit(repo);
    await cubit.load();

    expect(cubit.state, isA<FavoriteRequestsLoaded>());
    expect((cubit.state as FavoriteRequestsLoaded).requests.length, 1);
  });

  // ---------------------------------------------------------------------------
  // load() — empty list
  // ---------------------------------------------------------------------------
  test('load() empty list → FavoriteRequestsEmpty', () async {
    when(() => repo.packageRequests()).thenAnswer((_) async => []);

    final cubit = FavoriteRequestsCubit(repo);
    await cubit.load();

    expect(cubit.state, isA<FavoriteRequestsEmpty>());
  });

  // ---------------------------------------------------------------------------
  // load() — throws
  // ---------------------------------------------------------------------------
  test('load() throws → FavoriteRequestsError', () async {
    when(() => repo.packageRequests()).thenThrow(Exception('network error'));

    final cubit = FavoriteRequestsCubit(repo);
    await cubit.load();

    expect(cubit.state, isA<FavoriteRequestsError>());
  });

  // ---------------------------------------------------------------------------
  // refresh() — delegates to load()
  // ---------------------------------------------------------------------------
  test('refresh() non-empty list → FavoriteRequestsLoaded', () async {
    when(() => repo.packageRequests()).thenAnswer((_) async => [_makeItem()]);

    final cubit = FavoriteRequestsCubit(repo);
    await cubit.refresh();

    expect(cubit.state, isA<FavoriteRequestsLoaded>());
  });

  // ---------------------------------------------------------------------------
  // initial state
  // ---------------------------------------------------------------------------
  test('initial state is FavoriteRequestsLoading', () {
    final cubit = FavoriteRequestsCubit(repo);
    expect(cubit.state, isA<FavoriteRequestsLoading>());
  });

  test('load() transitions to Loaded with correct data', () async {
    final items = [_makeItem(), _makeItem()];
    when(() => repo.packageRequests()).thenAnswer((_) async => items);

    final cubit = FavoriteRequestsCubit(repo);
    await cubit.load();

    final state = cubit.state as FavoriteRequestsLoaded;
    expect(state.requests.length, 2);
  });
}
