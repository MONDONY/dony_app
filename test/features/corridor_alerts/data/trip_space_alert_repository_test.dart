import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/corridor_alerts/data/trip_space_alert_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

Response<T> _resp<T>(T? data, {int status = 200}) => Response<T>(
  requestOptions: RequestOptions(path: '/'),
  data: data,
  statusCode: status,
);

void main() {
  late _MockApiClient api;
  late _MockDio dio;
  late TripSpaceAlertRepository repo;

  setUp(() {
    api = _MockApiClient();
    dio = _MockDio();
    when(() => api.dio).thenReturn(dio);
    repo = TripSpaceAlertRepository(api);
  });

  test('getSubscribedTripIds lit les ids de trajets en attente', () async {
    when(() => dio.get<List<dynamic>>('/me/trip-space-alerts')).thenAnswer(
      (_) async => _resp<List<dynamic>>([
        {'announcementId': 'a1', 'createdAt': '2026-10-11T10:00:00'},
        {'announcementId': 'b2'},
        {'other': 'ignoré'},
      ]),
    );

    expect(await repo.getSubscribedTripIds(), {'a1', 'b2'});
  });

  test('getSubscribedTripIds : réponse vide → aucun', () async {
    when(
      () => dio.get<List<dynamic>>('/me/trip-space-alerts'),
    ).thenAnswer((_) async => _resp<List<dynamic>>(null));

    expect(await repo.getSubscribedTripIds(), isEmpty);
  });

  test('subscribe → PUT sur le trajet', () async {
    when(
      () => dio.put<Map<String, dynamic>>('/me/trip-space-alerts/a1'),
    ).thenAnswer(
      (_) async => _resp<Map<String, dynamic>>({'announcementId': 'a1'}),
    );

    await repo.subscribe('a1');

    verify(
      () => dio.put<Map<String, dynamic>>('/me/trip-space-alerts/a1'),
    ).called(1);
  });

  test('unsubscribe → DELETE sur le trajet', () async {
    when(
      () => dio.delete<void>('/me/trip-space-alerts/a1'),
    ).thenAnswer((_) async => _resp<void>(null, status: 204));

    await repo.unsubscribe('a1');

    verify(() => dio.delete<void>('/me/trip-space-alerts/a1')).called(1);
  });
}
