import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tracking/data/trip_tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late TripTrackingRepository repository;

  setUp(() {
    final apiClient = _MockApiClient();
    dio = _MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response(requestOptions: RequestOptions(), statusCode: 200),
    );
    repository = TripTrackingRepository(apiClient);
  });

  test('sendPosition posts lat and lon', () async {
    await repository.sendPosition('a1', 48.85, 2.35);
    verify(
      () => dio.post(
        '/announcements/a1/position',
        data: {'lat': 48.85, 'lon': 2.35},
      ),
    ).called(1);
  });

  test('depart sends the position when given', () async {
    await repository.depart('a1', lat: 48.85, lon: 2.35);
    verify(
      () => dio.post(
        '/announcements/a1/depart',
        data: {'lat': 48.85, 'lon': 2.35},
      ),
    ).called(1);
  });

  test('depart sends an empty body without position', () async {
    await repository.depart('a1');
    verify(() => dio.post('/announcements/a1/depart')).called(1);
  });
}
