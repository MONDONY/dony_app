import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/datasources/notification_prefs_remote_datasource.dart';
import 'package:dony/features/settings/data/models/notification_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/notification_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockDatasource extends Mock
    implements NotificationPrefsRemoteDatasource {}

class _FakeDto extends Fake implements NotificationPrefsDto {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDto());
  });

  group('NotificationPrefsRemoteDatasource', () {
    late MockApiClient mockApi;
    late MockDio mockDio;
    late NotificationPrefsRemoteDatasource datasource;

    setUp(() {
      mockApi = MockApiClient();
      mockDio = MockDio();
      when(() => mockApi.dio).thenReturn(mockDio);
      datasource = NotificationPrefsRemoteDatasource(mockApi);
    });

    test('fetchPrefs appelle GET /notifications/preferences et parse le DTO',
        () async {
      when(() => mockDio.get('/notifications/preferences')).thenAnswer(
        (_) async => Response(
          data: {
            'pushActivityBids': false,
            'pushActivityNegotiations': true,
            'pushMessages': false,
            'pushTripReminder': true,
            'pushPromo': true,
            'pushCorridorAlerts': false,
          },
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        ),
      );

      final dto = await datasource.fetchPrefs();

      expect(dto.values['push_activity_bids'], isFalse);
      expect(dto.values['push_activity_negotiations'], isTrue);
      expect(dto.values['push_messages'], isFalse);
      expect(dto.values['push_trip_reminder'], isTrue);
      expect(dto.values['push_promo'], isTrue);
      expect(dto.values['push_corridor_alerts'], isFalse);
    });

    test('updatePrefs appelle PUT /notifications/preferences avec les six champs',
        () async {
      const dto = NotificationPrefsDto({'push_messages': false});
      when(() => mockDio.put(
            '/notifications/preferences',
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        ),
      );

      await datasource.updatePrefs(dto);

      final data = verify(() => mockDio.put(
            '/notifications/preferences',
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(data.keys, hasLength(6));
      expect(data['pushMessages'], isFalse);
    });
  });

  group('NotificationPrefsRepository', () {
    late MockDatasource datasource;
    late NotificationPrefsRepository repository;

    setUp(() {
      datasource = MockDatasource();
      repository = NotificationPrefsRepository(datasource);
    });

    test('fetchPrefs délègue au datasource', () async {
      when(() => datasource.fetchPrefs())
          .thenAnswer((_) async => const NotificationPrefsDto({'push_promo': true}));

      final dto = await repository.fetchPrefs();

      expect(dto.values['push_promo'], isTrue);
      verify(() => datasource.fetchPrefs()).called(1);
    });

    test('updatePrefs délègue au datasource', () async {
      when(() => datasource.updatePrefs(any())).thenAnswer((_) async {});
      const dto = NotificationPrefsDto({'push_messages': false});

      await repository.updatePrefs(dto);

      verify(() => datasource.updatePrefs(dto)).called(1);
    });
  });
}
