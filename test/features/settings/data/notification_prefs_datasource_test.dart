import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/notification_prefs_datasource.dart';
import 'package:dony/features/settings/data/notification_prefs_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockNotificationPrefsDatasource extends Mock implements NotificationPrefsDatasource {}
class MockBox extends Mock implements Box<dynamic> {}

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
      expect(body['pushActivityNegotiations'], isTrue);
      expect(body['pushMessages'],             isTrue);
      expect(body['pushTripReminder'],         isTrue);
      expect(body['pushPromo'],                isFalse);
    });
  });

  group('NotificationPrefsRepository', () {
    late MockNotificationPrefsDatasource mockDatasource;
    late NotificationPrefsRepository repo;

    setUp(() {
      mockDatasource = MockNotificationPrefsDatasource();
      repo = NotificationPrefsRepository(mockDatasource);
    });

    test('syncPrefs délègue au datasource', () async {
      when(() => mockDatasource.syncPrefs(any())).thenAnswer((_) async {});
      const prefs = {'push_activity_bids': false, 'push_promo': true};

      await repo.syncPrefs(prefs);

      verify(() => mockDatasource.syncPrefs(prefs)).called(1);
    });

    test('syncPrefs ne lève pas si le datasource échoue', () async {
      when(() => mockDatasource.syncPrefs(any())).thenThrow(Exception('network error'));

      await expectLater(repo.syncPrefs({'push_activity_bids': true}), completes);
    });

    test('fetchAndApplyPrefs écrit les valeurs backend dans Hive', () async {
      final box = MockBox();
      when(() => mockDatasource.fetchPrefs()).thenAnswer((_) async => {
        'push_activity_bids':         false,
        'push_activity_negotiations': true,
        'push_messages':              false,
        'push_trip_reminder':         true,
        'push_promo':                 true,
      });
      when(() => box.put(any(), any())).thenAnswer((_) async {});

      await repo.fetchAndApplyPrefs(box);

      verify(() => box.put('notif_push_activity_bids',         false)).called(1);
      verify(() => box.put('notif_push_activity_negotiations', true)).called(1);
      verify(() => box.put('notif_push_messages',              false)).called(1);
      verify(() => box.put('notif_push_trip_reminder',         true)).called(1);
      verify(() => box.put('notif_push_promo',                 true)).called(1);
    });

    test('fetchAndApplyPrefs est silencieux si le datasource échoue', () async {
      final box = MockBox();
      when(() => mockDatasource.fetchPrefs()).thenThrow(Exception('network'));

      await expectLater(repo.fetchAndApplyPrefs(box), completes);
      verifyNever(() => box.put(any(), any()));
    });
  });

  group('NotificationPrefsDatasource.fetchPrefs', () {
    test('appelle GET /notifications/preferences et mappe camelCase → snake_case', () async {
      when(() => dio.get('/notifications/preferences')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/notifications/preferences'),
            statusCode: 200,
            data: {
              'pushActivityBids':         false,
              'pushActivityNegotiations': true,
              'pushMessages':             false,
              'pushTripReminder':         true,
              'pushPromo':                true,
            },
          ));

      final result = await datasource.fetchPrefs();

      expect(result['push_activity_bids'],         isFalse);
      expect(result['push_activity_negotiations'], isTrue);
      expect(result['push_messages'],              isFalse);
      expect(result['push_trip_reminder'],         isTrue);
      expect(result['push_promo'],                 isTrue);
    });

    test('fetchPrefs utilise les defaults si une clé est absente de la réponse', () async {
      when(() => dio.get('/notifications/preferences')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/notifications/preferences'),
            statusCode: 200,
            data: <String, dynamic>{},
          ));

      final result = await datasource.fetchPrefs();

      expect(result['push_activity_bids'],         isTrue);
      expect(result['push_activity_negotiations'], isTrue);
      expect(result['push_messages'],              isTrue);
      expect(result['push_trip_reminder'],         isTrue);
      expect(result['push_promo'],                 isFalse);
    });
  });
}
