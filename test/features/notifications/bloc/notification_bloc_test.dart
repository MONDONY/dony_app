import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

final _now = DateTime(2026, 4, 26, 12, 0);

NotificationModel _makeNotif({required String id, bool read = false}) =>
    NotificationModel(
      id: id,
      type: 'BID_CREATED',
      title: 'Test',
      body: 'Body',
      data: {},
      read: read,
      createdAt: _now,
    );

void main() {
  late MockNotificationRepository repository;

  setUp(() {
    repository = MockNotificationRepository();
  });

  group('NotificationBloc', () {
    // ── NotificationsLoadRequested ──────────────────────────────────────────

    blocTest<NotificationBloc, NotificationState>(
      'emits Loading then Loaded on success',
      build: () {
        when(() => repository.getNotifications()).thenAnswer(
          (_) async => [_makeNotif(id: '1'), _makeNotif(id: '2', read: true)],
        );
        when(() => repository.getUnreadCount()).thenAnswer((_) async => 1);
        return NotificationBloc(repository);
      },
      act: (bloc) => bloc.add(const NotificationsLoadRequested()),
      expect: () => [
        const NotificationLoading(),
        isA<NotificationLoaded>()
            .having((s) => s.notifications.length, 'count', 2)
            .having((s) => s.unreadCount, 'unread', 1),
      ],
    );

    blocTest<NotificationBloc, NotificationState>(
      'emits Loading then Error on failure',
      build: () {
        when(() => repository.getNotifications()).thenThrow(Exception('err'));
        when(() => repository.getUnreadCount()).thenAnswer((_) async => 0);
        return NotificationBloc(repository);
      },
      act: (bloc) => bloc.add(const NotificationsLoadRequested()),
      expect: () => [const NotificationLoading(), isA<NotificationError>()],
    );

    // ── NotificationMarkReadRequested ───────────────────────────────────────

    blocTest<NotificationBloc, NotificationState>(
      'marks single notification as read and decrements unreadCount',
      build: () {
        when(() => repository.markRead('1')).thenAnswer((_) async {});
        return NotificationBloc(repository);
      },
      seed: () => NotificationLoaded(
        notifications: [
          _makeNotif(id: '1', read: false),
          _makeNotif(id: '2', read: false),
        ],
        unreadCount: 2,
      ),
      act: (bloc) => bloc.add(const NotificationMarkReadRequested('1')),
      expect: () => [
        isA<NotificationLoaded>()
            .having((s) => s.notifications.first.read, 'first.read', true)
            .having((s) => s.notifications[1].read, 'second.read', false)
            .having((s) => s.unreadCount, 'unread', 1),
      ],
    );

    // ── NotificationsMarkAllReadRequested ───────────────────────────────────

    blocTest<NotificationBloc, NotificationState>(
      'marks all notifications as read and sets unreadCount to 0',
      build: () {
        when(() => repository.markAllRead()).thenAnswer((_) async {});
        return NotificationBloc(repository);
      },
      seed: () => NotificationLoaded(
        notifications: [
          _makeNotif(id: '1', read: false),
          _makeNotif(id: '2', read: false),
        ],
        unreadCount: 2,
      ),
      act: (bloc) => bloc.add(const NotificationsMarkAllReadRequested()),
      expect: () => [
        isA<NotificationLoaded>()
            .having(
              (s) => s.notifications.every((n) => n.read),
              'all read',
              true,
            )
            .having((s) => s.unreadCount, 'unread', 0),
      ],
    );

    // ── NotificationDeleteRequested ─────────────────────────────────────────

    blocTest<NotificationBloc, NotificationState>(
      'removes notification optimistically and updates unreadCount',
      build: () {
        when(() => repository.deleteNotification('1')).thenAnswer((_) async {});
        return NotificationBloc(repository);
      },
      seed: () => NotificationLoaded(
        notifications: [
          _makeNotif(id: '1', read: false),
          _makeNotif(id: '2', read: true),
        ],
        unreadCount: 1,
      ),
      act: (bloc) => bloc.add(const NotificationDeleteRequested('1')),
      expect: () => [
        isA<NotificationLoaded>()
            .having((s) => s.notifications.length, 'count', 1)
            .having((s) => s.notifications.first.id, 'remaining id', '2')
            .having((s) => s.unreadCount, 'unread', 0),
      ],
    );

    blocTest<NotificationBloc, NotificationState>(
      'restores previous state when delete API call fails',
      build: () {
        when(
          () => repository.deleteNotification('1'),
        ).thenThrow(Exception('network error'));
        return NotificationBloc(repository);
      },
      seed: () => NotificationLoaded(
        notifications: [_makeNotif(id: '1', read: false)],
        unreadCount: 1,
      ),
      act: (bloc) => bloc.add(const NotificationDeleteRequested('1')),
      expect: () => [
        isA<NotificationLoaded>().having(
          (s) => s.notifications.isEmpty,
          'optimistic empty',
          true,
        ),
        isA<NotificationLoaded>().having(
          (s) => s.notifications.length,
          'restored',
          1,
        ),
      ],
    );
  });
}
