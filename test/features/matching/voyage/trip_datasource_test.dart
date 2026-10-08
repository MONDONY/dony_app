import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_fixtures.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _leg(String id, String from, String to, int index) => {
  'id': id,
  'travelerId': 't',
  'departureCity': from,
  'arrivalCity': to,
  'departureDate': '2026-11-10',
  'availableKg': 10,
  'totalKg': 10,
  'status': 'ACTIVE',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
  'tripGroupId': 'g1',
  'tripLegIndex': index,
  'tripLegCount': 2,
};

void main() {
  late _MockDio dio;
  late AnnouncementRepository repository;

  setUp(() {
    final client = _MockApiClient();
    dio = _MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = AnnouncementRepository(AnnouncementRemoteDatasource(client));
  });

  final payload = AnnouncementPayload(
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    departureDate: DateTime(2026, 11, 10),
    pickupAddress: kParis,
    deliveryAddress: kAbidjan,
    availableKg: 20,
    pricePerKg: 8,
    transportMode: TransportMode.plane,
    handoverDeadline: DateTime.utc(2026, 11, 9),
  );

  test('createTrip poste toutes les étapes et lit la réponse', () async {
    when(
      () => dio.post('/announcements/trips', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        data: {
          'tripGroupId': 'g1',
          'legs': [
            _leg('a', 'Paris', 'Abidjan', 1),
            _leg('b', 'Abidjan', 'Douala', 2),
          ],
        },
        statusCode: 201,
        requestOptions: RequestOptions(path: '/announcements/trips'),
      ),
    );

    final legs = await repository.createTrip([payload, payload]);

    expect(legs.map((l) => l.id), ['a', 'b']);
    expect(legs[1].tripLegIndex, 2);
    final body =
        verify(
              () => dio.post(
                '/announcements/trips',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect((body['legs'] as List), hasLength(2));
    expect((body['legs'] as List).first, payload.toJson());
  });

  test('createTrip sans liste : aucune étape', () async {
    when(
      () => dio.post('/announcements/trips', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        data: <String, dynamic>{},
        statusCode: 201,
        requestOptions: RequestOptions(path: '/announcements/trips'),
      ),
    );
    expect(await repository.createTrip([payload]), isEmpty);
  });

  test('getTripLegs lit les étapes du voyage', () async {
    when(() => dio.get('/announcements/a/trip-legs')).thenAnswer(
      (_) async => Response(
        data: {
          'tripGroupId': 'g1',
          'legCount': 2,
          'legs': [
            {'id': 'a', 'legIndex': 1, 'departureDate': '2026-11-10'},
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/announcements/a/trip-legs'),
      ),
    );
    final info = await repository.getTripLegs('a');
    expect(info.tripGroupId, 'g1');
    expect(info.legCount, 2);
    expect(info.legs.single.id, 'a');
  });
}
