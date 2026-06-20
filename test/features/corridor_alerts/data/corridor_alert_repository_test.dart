import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
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

  test('getMyAlerts → GET /me/corridor-alerts', () async {
    when(() => dio.get<List<dynamic>>('/me/corridor-alerts'))
        .thenAnswer((_) async => _resp<List<dynamic>>([alertJson]));
    final result = await repo.getMyAlerts();
    expect(result, isA<List<CorridorAlertModel>>());
    expect(result.single.id, 'a1');
    verify(() => dio.get<List<dynamic>>('/me/corridor-alerts')).called(1);
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

  test('delete → DELETE /me/corridor-alerts/{id}', () async {
    when(() => dio.delete<void>('/me/corridor-alerts/a1'))
        .thenAnswer((_) async => _resp<void>(null));
    await repo.delete('a1');
    verify(() => dio.delete<void>('/me/corridor-alerts/a1')).called(1);
  });

  test('getMatches → GET /me/corridor-alerts/{id}/matches', () async {
    when(() => dio.get<List<dynamic>>('/me/corridor-alerts/a1/matches'))
        .thenAnswer((_) async => _resp<List<dynamic>>([]));
    final matches = await repo.getMatches('a1');
    expect(matches, isEmpty);
    verify(() => dio.get<List<dynamic>>('/me/corridor-alerts/a1/matches'))
        .called(1);
  });
}
