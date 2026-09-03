import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/notifications/data/announcements_summary.dart';
import 'package:dony/features/notifications/data/notification_model.dart';

abstract class NotificationState {
  const NotificationState();
}

class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

class NotificationLoaded extends NotificationState {
  /// Le feed : tout sauf les annonces plateforme, groupes non lus repliés.
  final List<NotificationModel> notifications;

  /// Compteur global servi par le serveur : feed plus annonces, en événements.
  final int unreadCount;

  /// La carte « Annonces Yadony » ; vide tant que le serveur ne l'a pas servie.
  final AnnouncementsSummary announcements;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
    this.announcements = AnnouncementsSummary.empty,
  });

  NotificationLoaded copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    AnnouncementsSummary? announcements,
  }) {
    return NotificationLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      announcements: announcements ?? this.announcements,
    );
  }
}

class NotificationError extends NotificationState {
  final AppException error;
  const NotificationError(this.error);
}
