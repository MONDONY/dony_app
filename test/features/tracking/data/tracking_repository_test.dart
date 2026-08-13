import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockApiClient apiClient;
  late _MockDio dio;
  late TrackingRepository repository;

  setUp(() {
    apiClient = _MockApiClient();
    dio = _MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    repository = TrackingRepository(apiClient);
  });

  group('getTripScanHistory', () {
    test('maps the response list to TripScanHistoryEntryModel', () async {
      when(() => dio.get('/tracking/announcements/trip-1/events')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: [
            {
              'donNumber': 'TRK000001',
              'recipientName': 'Awa Ndiaye',
              'eventType': 'DEPART',
              'scannedAt': '2026-06-20T14:32:00',
            },
          ],
        ),
      );

      final result = await repository.getTripScanHistory('trip-1');

      expect(result, hasLength(1));
      expect(result.first.donNumber, 'TRK000001');
      expect(result.first.eventType, 'DEPART');
    });
  });
}
