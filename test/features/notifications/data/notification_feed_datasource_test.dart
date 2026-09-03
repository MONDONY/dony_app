import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/notifications/data/notification_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient apiClient;
  late MockDio dio;
  late NotificationRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    dio = MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    datasource = NotificationRemoteDatasource(apiClient);
  });

  final aggregateJson = {
    'id': 'latest',
    'type': 'BID_CREATED',
    'category': 'colis',
    'title': '3 demandes d\'envoi',
    'body': 'Karim T., 12 kg, Paris vers Dakar.',
    'deeplink': 'yadony://announcements/a1/bids',
    'groupKey': 'bid:announcement:a1',
    'data': {'type': 'BID_CREATED'},
    'read': false,
    'createdAt': '2026-09-03T10:00:00.000Z',
    'count': 3,
    'notificationIds': ['latest', 'n2', 'n3'],
  };

  group('fetchFeed', () {
    test('appelle /notifications/feed et lit les lignes agrégées', () async {
      when(
        () => dio.get(
          '/notifications/feed',
          queryParameters: {'page': 0, 'size': 30},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'content': [aggregateJson],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: '/notifications/feed'),
        ),
      );

      final result = await datasource.fetchFeed();

      expect(result.length, 1);
      expect(result.first.isAggregate, isTrue);
      expect(result.first.count, 3);
      expect(result.first.groupKey, 'bid:announcement:a1');
    });

    test('passe la page demandée', () async {
      when(
        () => dio.get(
          '/notifications/feed',
          queryParameters: {'page': 2, 'size': 30},
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {'content': <dynamic>[]},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/notifications/feed'),
        ),
      );

      final result = await datasource.fetchFeed(page: 2);

      expect(result, isEmpty);
    });
  });

  test('markGroupRead envoie la clé en paramètre de requête', () async {
    when(
      () => dio.patch(
        '/notifications/groups/read',
        queryParameters: {'groupKey': 'bid:announcement:a1'},
      ),
    ).thenAnswer(
      (_) async => Response(
        data: {'count': 3},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/notifications/groups/read'),
      ),
    );

    await datasource.markGroupRead('bid:announcement:a1');

    verify(
      () => dio.patch(
        '/notifications/groups/read',
        queryParameters: {'groupKey': 'bid:announcement:a1'},
      ),
    ).called(1);
  });
}
