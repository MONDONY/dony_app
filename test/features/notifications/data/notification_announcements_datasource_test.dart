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

  test('fetchAnnouncements appelle /notifications/annonces', () async {
    when(
      () => dio.get(
        '/notifications/annonces',
        queryParameters: {'page': 0, 'size': 30},
      ),
    ).thenAnswer(
      (_) async => Response(
        data: {
          'content': [
            {
              'id': 'a1',
              'type': 'ADMIN_BROADCAST',
              'category': 'annonce',
              'title': 'Maintenance',
              'body': 'Corps court.',
              'groupKey': 'notif:a1',
              'data': {'type': 'ADMIN_BROADCAST'},
              'read': false,
              'createdAt': '2026-09-03T10:00:00.000Z',
              'count': 1,
              'notificationIds': ['a1'],
            },
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/notifications/annonces'),
      ),
    );

    final result = await datasource.fetchAnnouncements();

    expect(result.single.id, 'a1');
    expect(result.single.category, 'annonce');
    expect(result.single.deeplink, isNull);
  });

  test('fetchAnnouncementsSummary lit la carte', () async {
    when(() => dio.get('/notifications/annonces/summary')).thenAnswer(
      (_) async => Response(
        data: {
          'unreadCount': 2,
          'latestId': 'a1',
          'latestTitle': 'Maintenance',
          'latestAt': '2026-09-03T10:00:00',
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/notifications/annonces/summary'),
      ),
    );

    final summary = await datasource.fetchAnnouncementsSummary();

    expect(summary.unreadCount, 2);
    expect(summary.latestId, 'a1');
    expect(summary.latestTitle, 'Maintenance');
  });
}
