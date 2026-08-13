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

  final notifJson = {
    'id': 'notif-1',
    'type': 'BID_ACCEPTED',
    'title': 'Demande acceptée !',
    'body': 'Ibrahima accepte votre colis',
    'data': {'type': 'BID_ACCEPTED', 'bidId': 'bid-1'},
    'read': false,
    'createdAt': '2026-04-26T12:00:00.000Z',
  };

  group('NotificationRemoteDatasource', () {
    group('fetchNotifications', () {
      test('returns list of NotificationModel on success', () async {
        when(
          () => dio.get(
            '/notifications',
            queryParameters: {'page': 0, 'size': 30},
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'content': [notifJson],
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/notifications'),
          ),
        );

        final result = await datasource.fetchNotifications();

        expect(result.length, 1);
        expect(result.first.id, 'notif-1');
        expect(result.first.type, 'BID_ACCEPTED');
        expect(result.first.read, false);
      });

      test('returns empty list when content is empty', () async {
        when(
          () => dio.get(
            '/notifications',
            queryParameters: {'page': 0, 'size': 30},
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {'content': []},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/notifications'),
          ),
        );

        final result = await datasource.fetchNotifications();

        expect(result, isEmpty);
      });

      test('throws on API error', () async {
        when(
          () => dio.get(
            '/notifications',
            queryParameters: {'page': 0, 'size': 30},
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/notifications'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        expect(datasource.fetchNotifications(), throwsA(isA<DioException>()));
      });
    });

    group('fetchUnreadCount', () {
      test('returns count from API', () async {
        when(() => dio.get('/notifications/unread-count')).thenAnswer(
          (_) async => Response(
            data: {'count': 5},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/notifications/unread-count'),
          ),
        );

        final count = await datasource.fetchUnreadCount();

        expect(count, 5);
      });

      test('returns 0 when count field is null', () async {
        when(() => dio.get('/notifications/unread-count')).thenAnswer(
          (_) async => Response(
            data: {'count': null},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/notifications/unread-count'),
          ),
        );

        final count = await datasource.fetchUnreadCount();

        expect(count, 0);
      });
    });

    group('markRead', () {
      test('calls PATCH /notifications/{id}/read', () async {
        when(() => dio.patch('/notifications/notif-1/read')).thenAnswer(
          (_) async => Response(
            statusCode: 204,
            requestOptions: RequestOptions(path: '/notifications/notif-1/read'),
          ),
        );

        await datasource.markRead('notif-1');

        verify(() => dio.patch('/notifications/notif-1/read')).called(1);
      });
    });

    group('markAllRead', () {
      test('calls PATCH /notifications/read-all', () async {
        when(() => dio.patch('/notifications/read-all')).thenAnswer(
          (_) async => Response(
            statusCode: 204,
            requestOptions: RequestOptions(path: '/notifications/read-all'),
          ),
        );

        await datasource.markAllRead();

        verify(() => dio.patch('/notifications/read-all')).called(1);
      });
    });

    group('deleteNotification', () {
      test('calls DELETE /notifications/{id}', () async {
        when(() => dio.delete('/notifications/notif-1')).thenAnswer(
          (_) async => Response(
            statusCode: 204,
            requestOptions: RequestOptions(path: '/notifications/notif-1'),
          ),
        );

        await datasource.deleteNotification('notif-1');

        verify(() => dio.delete('/notifications/notif-1')).called(1);
      });
    });

    group('ack', () {
      test('calls POST /notifications/{id}/ack', () async {
        when(() => dio.post('/notifications/notif-1/ack')).thenAnswer(
          (_) async => Response(
            statusCode: 204,
            requestOptions: RequestOptions(path: '/notifications/notif-1/ack'),
          ),
        );

        await datasource.ack('notif-1');

        verify(() => dio.post('/notifications/notif-1/ack')).called(1);
      });
    });
  });
}
