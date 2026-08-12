// ignore_for_file: prefer_const_constructors
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final _notif = NotificationModel(
    id: 'n1',
    type: 'BID_ACCEPTED',
    title: 'Titre',
    body: 'Corps',
    data: {},
    read: false,
    createdAt: DateTime(2026, 4, 26),
  );

  group('NotificationEvent', () {
    test('NotificationsLoadRequested is instantiable', () {
      expect(NotificationsLoadRequested(), isA<NotificationEvent>());
    });

    test('NotificationMarkReadRequested stores id', () {
      final event = NotificationMarkReadRequested('n1');
      expect(event.id, 'n1');
    });

    test('NotificationsMarkAllReadRequested is instantiable', () {
      expect(NotificationsMarkAllReadRequested(), isA<NotificationEvent>());
    });

    test('NotificationDeleteRequested stores id', () {
      final event = NotificationDeleteRequested('n1');
      expect(event.id, 'n1');
    });
  });

  group('NotificationState', () {
    test('NotificationInitial is a NotificationState', () {
      expect(const NotificationInitial(), isA<NotificationState>());
    });

    test('NotificationLoading is a NotificationState', () {
      expect(const NotificationLoading(), isA<NotificationState>());
    });

    test('NotificationError stores message', () {
      final state = NotificationError(NetworkException('Erreur réseau'));
      expect(state.error.message, 'Erreur réseau');
    });

    test('NotificationLoaded copyWith updates notifications', () {
      final original = NotificationLoaded(notifications: [_notif], unreadCount: 1);
      final updated = original.copyWith(notifications: []);
      expect(updated.notifications, isEmpty);
      expect(updated.unreadCount, 1);
    });

    test('NotificationLoaded copyWith updates unreadCount', () {
      final original = NotificationLoaded(notifications: [_notif], unreadCount: 1);
      final updated = original.copyWith(unreadCount: 0);
      expect(updated.unreadCount, 0);
      expect(updated.notifications, [_notif]);
    });
  });
}
