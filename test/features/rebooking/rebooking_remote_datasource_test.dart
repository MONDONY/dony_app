import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/rebooking/data/rebooking_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

final _bookingJson = {
  'bidId': 'bid-1',
  'travelerId': 'traveler-1',
  'travelerName': 'Amadou Diallo',
  'travelerBadge': 'PRO',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'lastTripDate': '2026-04-01',
  'completedTripsWithThisTraveler': 3,
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late RebookingRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = RebookingRemoteDatasource(mockClient);
  });

  group('getPastBookings', () {
    test('parse la liste des réservations passées', () async {
      when(() => mockDio.get('/senders/me/past-bookings')).thenAnswer(
        (_) async => _ok([_bookingJson], '/senders/me/past-bookings'),
      );

      final result = await datasource.getPastBookings();

      expect(result, hasLength(1));
      final b = result.first;
      expect(b.bidId, 'bid-1');
      expect(b.travelerName, 'Amadou Diallo');
      expect(b.travelerBadge, 'PRO');
      expect(b.departureCity, 'Paris');
      expect(b.arrivalCity, 'Dakar');
      expect(b.lastTripDate, DateTime(2026, 4, 1));
      expect(b.completedTripsWithThisTraveler, 3);
    });

    test('retourne une liste vide', () async {
      when(() => mockDio.get('/senders/me/past-bookings'))
          .thenAnswer((_) async => _ok([], '/senders/me/past-bookings'));

      expect(await datasource.getPastBookings(), isEmpty);
    });
  });

  group('rebook', () {
    test('parse REBOOKED avec newBidId', () async {
      when(() => mockDio.post('/bookings/rebook/bid-1')).thenAnswer(
        (_) async => _ok(
          {'status': 'REBOOKED', 'newBidId': 'new-1'},
          '/bookings/rebook/bid-1',
        ),
      );

      final result = await datasource.rebook('bid-1');

      expect(result.status, 'REBOOKED');
      expect(result.newBidId, 'new-1');
    });

    test('parse NO_UPCOMING_TRIP avec newBidId null', () async {
      when(() => mockDio.post('/bookings/rebook/bid-2')).thenAnswer(
        (_) async => _ok(
          {'status': 'NO_UPCOMING_TRIP', 'newBidId': null},
          '/bookings/rebook/bid-2',
        ),
      );

      final result = await datasource.rebook('bid-2');

      expect(result.status, 'NO_UPCOMING_TRIP');
      expect(result.newBidId, isNull);
    });
  });

  group('subscribeToTraveler', () {
    test('POST /travelers/{id}/notify-when-available', () async {
      when(() => mockDio.post('/travelers/traveler-1/notify-when-available'))
          .thenAnswer(
        (_) async => _ok(null, '/travelers/traveler-1/notify-when-available'),
      );

      await datasource.subscribeToTraveler('traveler-1');

      verify(() =>
              mockDio.post('/travelers/traveler-1/notify-when-available'))
          .called(1);
    });
  });
}
