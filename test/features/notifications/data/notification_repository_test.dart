import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/data/notification_remote_datasource.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatasource extends Mock implements NotificationRemoteDatasource {}

void main() {
  late MockDatasource datasource;
  late NotificationRepository repository;

  final notif = NotificationModel(
    id: 'n1',
    type: 'BID_ACCEPTED',
    title: 'Demande acceptée !',
    body: 'Corps',
    data: {},
    read: false,
    createdAt: DateTime(2026, 4, 26),
  );

  setUp(() {
    datasource = MockDatasource();
    repository = NotificationRepository(datasource);
  });

  group('NotificationRepository', () {
    test('getNotifications delegates to datasource', () async {
      when(
        () => datasource.fetchNotifications(),
      ).thenAnswer((_) async => [notif]);

      final result = await repository.getNotifications();

      expect(result.length, 1);
      expect(result.first.id, 'n1');
      verify(() => datasource.fetchNotifications()).called(1);
    });

    test('getNotifications with page=2 passes page to datasource', () async {
      when(
        () => datasource.fetchNotifications(page: 2),
      ).thenAnswer((_) async => []);

      await repository.getNotifications(page: 2);

      verify(() => datasource.fetchNotifications(page: 2)).called(1);
    });

    test('getFeed delegates to datasource with the page', () async {
      when(
        () => datasource.fetchFeed(page: 1),
      ).thenAnswer((_) async => [notif]);

      final result = await repository.getFeed(page: 1);

      expect(result, [notif]);
      verify(() => datasource.fetchFeed(page: 1)).called(1);
    });

    test('markGroupRead delegates to datasource', () async {
      when(
        () => datasource.markGroupRead('bid:announcement:a'),
      ).thenAnswer((_) async {});

      await repository.markGroupRead('bid:announcement:a');

      verify(() => datasource.markGroupRead('bid:announcement:a')).called(1);
    });

    test('getUnreadCount delegates to datasource', () async {
      when(() => datasource.fetchUnreadCount()).thenAnswer((_) async => 3);

      final count = await repository.getUnreadCount();

      expect(count, 3);
    });

    test('markRead delegates to datasource', () async {
      when(() => datasource.markRead('n1')).thenAnswer((_) async {});

      await repository.markRead('n1');

      verify(() => datasource.markRead('n1')).called(1);
    });

    test('markAllRead delegates to datasource', () async {
      when(() => datasource.markAllRead()).thenAnswer((_) async {});

      await repository.markAllRead();

      verify(() => datasource.markAllRead()).called(1);
    });

    test('deleteNotification delegates to datasource', () async {
      when(() => datasource.deleteNotification('n1')).thenAnswer((_) async {});

      await repository.deleteNotification('n1');

      verify(() => datasource.deleteNotification('n1')).called(1);
    });

    test('propagates exception from datasource', () async {
      when(
        () => datasource.fetchNotifications(),
      ).thenThrow(Exception('network error'));

      expect(() async => await repository.getNotifications(), throwsException);
    });

    test('ack delegates to datasource', () async {
      when(() => datasource.ack('n1')).thenAnswer((_) async {});

      await repository.ack('n1');

      verify(() => datasource.ack('n1')).called(1);
    });
  });
}
