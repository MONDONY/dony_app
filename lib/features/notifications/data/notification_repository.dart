import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/data/notification_remote_datasource.dart';

class NotificationRepository {
  final NotificationRemoteDatasource _datasource;

  NotificationRepository(this._datasource);

  Future<List<NotificationModel>> getNotifications({int page = 0}) =>
      _datasource.fetchNotifications(page: page);

  Future<int> getUnreadCount() => _datasource.fetchUnreadCount();

  Future<void> markRead(String id) => _datasource.markRead(id);

  Future<void> markAllRead() => _datasource.markAllRead();

  Future<void> deleteNotification(String id) =>
      _datasource.deleteNotification(id);

  Future<void> ack(String id) => _datasource.ack(id);
}
