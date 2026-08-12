import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<T> _resp<T>(T data) => Response<T>(
  requestOptions: RequestOptions(path: '/'),
  data: data,
  statusCode: 200,
);

void main() {
  late MockApiClient api;
  late MockDio dio;
  late CorridorAlertRepository repo;

  setUp(() {
    api = MockApiClient();
    dio = MockDio();
    when(() => api.dio).thenReturn(dio);
    repo = CorridorAlertRepository(api);
  });

  final alertJson = <String, dynamic>{
    'id': 'a1',
    'departureCity': 'Paris',
    'arrivalCity': 'Bamako',
    'active': true,
    'matchCount': 2,
    'createdAt': '2026-06-20T09:00:00',
  };

  final packageMatchJson = <String, dynamic>{
    'id': 'm1',
    'senderId': 's1',
    'senderName': 'Jean D.',
    'senderInitials': 'JD',
    'senderRating': 4.5,
    'senderTotalSent': 10,
    'weightKg': 5.0,
    'matchScore': 80,
    'requestedAt': '2026-06-20T09:00:00',
  };

  final tripMatchJson = <String, dynamic>{
    'announcementId': 'ann-1',
    'departureCity': 'Paris',
    'arrivalCity': 'Dakar',
    'departureDate': '2026-07-10',
    'travelerId': 't-1',
    'travelerName': 'Awa S.',
    'travelerInitials': 'AS',
    'travelerRating': 4.7,
    'availableKg': 12.0,
  };

  test('getMyAlerts → GET /me/corridor-alerts', () async {
    when(
      () => dio.get<List<dynamic>>(
        '/me/corridor-alerts',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => _resp<List<dynamic>>([alertJson]));
    final result = await repo.getMyAlerts();
    expect(result, isA<List<CorridorAlertModel>>());
    expect(result.single.id, 'a1');
    verify(
      () => dio.get<List<dynamic>>(
        '/me/corridor-alerts',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).called(1);
  });

  test('create → POST /me/corridor-alerts with draft body', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/me/corridor-alerts',
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _resp<Map<String, dynamic>>(alertJson));
    const draft = CorridorAlertDraft(
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
    );
    final created = await repo.create(draft);
    expect(created.id, 'a1');
    verify(
      () => dio.post<Map<String, dynamic>>(
        '/me/corridor-alerts',
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  test('update → PUT /me/corridor-alerts/{id}', () async {
    when(
      () => dio.put<Map<String, dynamic>>(
        '/me/corridor-alerts/a1',
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _resp<Map<String, dynamic>>(alertJson));
    const draft = CorridorAlertDraft(
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
    );
    final updated = await repo.update('a1', draft);
    expect(updated.id, 'a1');
    verify(
      () => dio.put<Map<String, dynamic>>(
        '/me/corridor-alerts/a1',
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  test(
    'update with active:false → PUT body contains "active": false',
    () async {
      Map<String, dynamic>? capturedBody;
      when(
        () => dio.put<Map<String, dynamic>>(
          '/me/corridor-alerts/a1',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        capturedBody = inv.namedArguments[#data] as Map<String, dynamic>;
        return _resp<Map<String, dynamic>>(alertJson);
      });
      const draft = CorridorAlertDraft(
        departureCity: 'Paris',
        arrivalCity: 'Bamako',
      );
      await repo.update('a1', draft, active: false);
      expect(capturedBody, containsPair('active', false));
      verify(
        () => dio.put<Map<String, dynamic>>(
          '/me/corridor-alerts/a1',
          data: any(named: 'data'),
        ),
      ).called(1);
    },
  );

  test('update without active → PUT body omits "active"', () async {
    Map<String, dynamic>? capturedBody;
    when(
      () => dio.put<Map<String, dynamic>>(
        '/me/corridor-alerts/a1',
        data: any(named: 'data'),
      ),
    ).thenAnswer((inv) async {
      capturedBody = inv.namedArguments[#data] as Map<String, dynamic>;
      return _resp<Map<String, dynamic>>(alertJson);
    });
    const draft = CorridorAlertDraft(
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
    );
    await repo.update('a1', draft);
    expect(capturedBody!.containsKey('active'), isFalse);
    verify(
      () => dio.put<Map<String, dynamic>>(
        '/me/corridor-alerts/a1',
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  test('delete → DELETE /me/corridor-alerts/{id}', () async {
    when(
      () => dio.delete<void>('/me/corridor-alerts/a1'),
    ).thenAnswer((_) async => _resp<void>(null));
    await repo.delete('a1');
    verify(() => dio.delete<void>('/me/corridor-alerts/a1')).called(1);
  });

  test('getMatches → GET /me/corridor-alerts/{id}/matches (empty)', () async {
    when(
      () => dio.get<List<dynamic>>('/me/corridor-alerts/a1/matches'),
    ).thenAnswer((_) async => _resp<List<dynamic>>([]));
    final result = await repo.getMatches(
      'a1',
      AlertDirection.travelerWantsPackages,
    );
    expect(result.isEmpty, isTrue);
    verify(
      () => dio.get<List<dynamic>>('/me/corridor-alerts/a1/matches'),
    ).called(1);
  });

  test('getMyAlerts with direction → adds query param', () async {
    when(
      () => dio.get<List<dynamic>>(
        '/me/corridor-alerts',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => _resp<List<dynamic>>([alertJson]));
    await repo.getMyAlerts(direction: AlertDirection.senderWantsTrips);
    final captured =
        verify(
              () => dio.get<List<dynamic>>(
                '/me/corridor-alerts',
                queryParameters: captureAny(named: 'queryParameters'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured['direction'], 'SENDER_WANTS_TRIPS');
  });

  test('getMyAlerts without direction → no query param', () async {
    when(
      () => dio.get<List<dynamic>>(
        '/me/corridor-alerts',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => _resp<List<dynamic>>([alertJson]));
    await repo.getMyAlerts();
    final captured =
        verify(
              () => dio.get<List<dynamic>>(
                '/me/corridor-alerts',
                queryParameters: captureAny(named: 'queryParameters'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured.containsKey('direction'), isFalse);
  });

  test(
    'getMatches package direction → parses MatchingRequestModel list',
    () async {
      when(
        () => dio.get<List<dynamic>>('/me/corridor-alerts/a1/matches'),
      ).thenAnswer((_) async => _resp<List<dynamic>>([packageMatchJson]));
      final result = await repo.getMatches(
        'a1',
        AlertDirection.travelerWantsPackages,
      );
      expect(result.direction, AlertDirection.travelerWantsPackages);
      expect(result.packages, hasLength(1));
      expect(result.trips, isEmpty);
      expect(result.isEmpty, isFalse);
    },
  );

  test('getMatches trip direction → parses TripMatchModel list', () async {
    when(
      () => dio.get<List<dynamic>>('/me/corridor-alerts/a1/matches'),
    ).thenAnswer((_) async => _resp<List<dynamic>>([tripMatchJson]));
    final result = await repo.getMatches('a1', AlertDirection.senderWantsTrips);
    expect(result.direction, AlertDirection.senderWantsTrips);
    expect(result.trips, hasLength(1));
    expect(result.packages, isEmpty);
  });
}
