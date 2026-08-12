import 'package:dony/features/favorites/data/datasources/favorite_remote_datasource.dart';
import 'package:dony/features/favorites/data/models/favorite_ids.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockDatasource extends Mock implements FavoriteRemoteDatasource {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AnnouncementModel _makeTrip() => AnnouncementModel.fromJson({
  'id': 'trip-1',
  'travelerId': 'tv1',
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

PackageRequestSearchItem _makeRequest() => PackageRequestSearchItem(
  id: 'req-1',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  desiredDate: DateTime(2025, 7, 1),
  dateToleranceDays: 3,
  weightKg: 4.0,
  parcelSize: ParcelSize.medium,
  sender: const SenderPublicProfile(
    id: 's1',
    displayName: 'Moussa',
    averageRating: 4.5,
    totalRatings: 8,
    kycVerified: true,
  ),
);

void main() {
  late _MockDatasource ds;
  late FavoriteRepository repo;

  setUp(() {
    ds = _MockDatasource();
    repo = FavoriteRepository(ds);
  });

  // ---------------------------------------------------------------------------
  // add() — pass-through
  // ---------------------------------------------------------------------------
  group('add()', () {
    test('delegates to datasource.add(type, id)', () async {
      when(() => ds.add('trip', 't1')).thenAnswer((_) async {});

      await repo.add('trip', 't1');

      verify(() => ds.add('trip', 't1')).called(1);
    });

    test('delegates for package-request type', () async {
      when(() => ds.add('package-request', 'r1')).thenAnswer((_) async {});

      await repo.add('package-request', 'r1');

      verify(() => ds.add('package-request', 'r1')).called(1);
    });

    test('propagates error from datasource', () async {
      when(
        () => ds.add(any(), any()),
      ).thenAnswer((_) async => throw Exception('network'));

      await expectLater(repo.add('trip', 't1'), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // remove() — pass-through
  // ---------------------------------------------------------------------------
  group('remove()', () {
    test('delegates to datasource.remove(type, id)', () async {
      when(() => ds.remove('trip', 't1')).thenAnswer((_) async {});

      await repo.remove('trip', 't1');

      verify(() => ds.remove('trip', 't1')).called(1);
    });

    test('propagates error from datasource', () async {
      when(
        () => ds.remove(any(), any()),
      ).thenAnswer((_) async => throw Exception('network'));

      await expectLater(repo.remove('trip', 't1'), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // ids() — pass-through
  // ---------------------------------------------------------------------------
  group('ids()', () {
    test('delegates to datasource.ids() and returns result', () async {
      const expected = FavoriteIds(
        trips: {'t1', 't2'},
        packageRequests: {'r1'},
      );
      when(() => ds.ids()).thenAnswer((_) async => expected);

      final result = await repo.ids();

      expect(result.trips, containsAll(['t1', 't2']));
      expect(result.packageRequests, contains('r1'));
      verify(() => ds.ids()).called(1);
    });

    test('propagates error from datasource', () async {
      when(() => ds.ids()).thenAnswer((_) async => throw Exception('network'));

      await expectLater(repo.ids(), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // trips() — pass-through
  // ---------------------------------------------------------------------------
  group('trips()', () {
    test('delegates to datasource.trips() and returns list', () async {
      when(() => ds.trips()).thenAnswer((_) async => [_makeTrip()]);

      final result = await repo.trips();

      expect(result, hasLength(1));
      expect(result.first.id, 'trip-1');
      verify(() => ds.trips()).called(1);
    });

    test('returns empty list when datasource returns empty', () async {
      when(() => ds.trips()).thenAnswer((_) async => []);

      final result = await repo.trips();

      expect(result, isEmpty);
    });

    test('propagates error from datasource', () async {
      when(
        () => ds.trips(),
      ).thenAnswer((_) async => throw Exception('network'));

      await expectLater(repo.trips(), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // packageRequests() — pass-through
  // ---------------------------------------------------------------------------
  group('packageRequests()', () {
    test(
      'delegates to datasource.packageRequests() and returns list',
      () async {
        when(
          () => ds.packageRequests(),
        ).thenAnswer((_) async => [_makeRequest()]);

        final result = await repo.packageRequests();

        expect(result, hasLength(1));
        expect(result.first.id, 'req-1');
        verify(() => ds.packageRequests()).called(1);
      },
    );

    test('returns empty list when datasource returns empty', () async {
      when(() => ds.packageRequests()).thenAnswer((_) async => []);

      final result = await repo.packageRequests();

      expect(result, isEmpty);
    });

    test('propagates error from datasource', () async {
      when(
        () => ds.packageRequests(),
      ).thenAnswer((_) async => throw Exception('network'));

      await expectLater(repo.packageRequests(), throwsException);
    });
  });
}
