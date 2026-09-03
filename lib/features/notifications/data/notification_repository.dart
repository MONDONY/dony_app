import 'package:dony/features/notifications/data/announcements_summary.dart';
import 'package:dony/features/notifications/data/notification_detail.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/data/notification_remote_datasource.dart';

class NotificationRepository {
  final NotificationRemoteDatasource _datasource;

  NotificationRepository(this._datasource);

  Future<List<NotificationModel>> getNotifications({int page = 0}) =>
      _datasource.fetchNotifications(page: page);

  Future<List<NotificationModel>> getFeed({int page = 0}) =>
      _datasource.fetchFeed(page: page);

  Future<List<NotificationModel>> getAnnouncements({int page = 0}) =>
      _datasource.fetchAnnouncements(page: page);

  Future<AnnouncementsSummary> getAnnouncementsSummary() =>
      _datasource.fetchAnnouncementsSummary();

  Future<NotificationDetail> getDetail(String id) =>
      _datasource.fetchDetail(id);

  Future<int> getUnreadCount() => _datasource.fetchUnreadCount();

  Future<void> markRead(String id) => _datasource.markRead(id);

  Future<void> markGroupRead(String groupKey) =>
      _datasource.markGroupRead(groupKey);

  Future<void> markAllRead() => _datasource.markAllRead();

  Future<void> deleteNotification(String id) =>
      _datasource.deleteNotification(id);

  Future<void> ack(String id) => _datasource.ack(id);
}
