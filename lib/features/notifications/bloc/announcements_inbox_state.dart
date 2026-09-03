import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/notifications/data/notification_model.dart';

sealed class AnnouncementsInboxState {
  const AnnouncementsInboxState();
}

class AnnouncementsInboxInitial extends AnnouncementsInboxState {
  const AnnouncementsInboxInitial();
}

class AnnouncementsInboxLoading extends AnnouncementsInboxState {
  const AnnouncementsInboxLoading();
}

class AnnouncementsInboxLoaded extends AnnouncementsInboxState {
  final List<NotificationModel> announcements;

  const AnnouncementsInboxLoaded(this.announcements);

  /// Dérivé de la liste : c'est ce que la carte du sheet doit retrouver après
  /// rechargement, jamais un compteur qui vivrait sa vie à part.
  int get unreadCount => announcements.where((a) => !a.read).length;
}

class AnnouncementsInboxError extends AnnouncementsInboxState {
  final AppException error;
  const AnnouncementsInboxError(this.error);
}
