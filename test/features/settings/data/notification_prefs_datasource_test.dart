import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/notification_prefs_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient apiClient;
  late MockDio dio;
  late NotificationPrefsDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    dio = MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    datasource = NotificationPrefsDatasource(apiClient);
  });

  group('NotificationPrefsDatasource', () {
    test('syncPrefs appelle PUT /notifications/preferences avec body camelCase', () async {
      when(() => dio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/notifications/preferences'),
                statusCode: 204,
              ));

      await datasource.syncPrefs({
        'push_activity_bids':         false,
        'push_activity_negotiations': true,
        'push_messages':              true,
        'push_trip_reminder':         false,
        'push_promo':                 true,
      });

      final captured = verify(() => dio.put(
        '/notifications/preferences',
        data: captureAny(named: 'data'),
      )).captured;

      final body = captured.first as Map<String, dynamic>;
      expect(body['pushActivityBids'],         isFalse);
      expect(body['pushActivityNegotiations'], isTrue);
      expect(body['pushMessages'],             isTrue);
      expect(body['pushTripReminder'],         isFalse);
      expect(body['pushPromo'],                isTrue);
    });

    test('syncPrefs utilise les valeurs par défaut pour les clés manquantes', () async {
      when(() => dio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/notifications/preferences'),
                statusCode: 204,
              ));

      await datasource.syncPrefs({});

      final captured = verify(() => dio.put(any(), data: captureAny(named: 'data'))).captured;
      final body = captured.first as Map<String, dynamic>;
      expect(body['pushActivityBids'],         isTrue);
      expect(body['pushPromo'],                isFalse);
    });
  });
}
