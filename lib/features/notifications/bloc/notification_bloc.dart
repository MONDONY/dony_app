import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;

  NotificationBloc(this._repository) : super(const NotificationInitial()) {
    on<NotificationsLoadRequested>(_onLoad);
    on<NotificationMarkReadRequested>(_onMarkRead);
    on<NotificationsMarkAllReadRequested>(_onMarkAllRead);
    on<NotificationDeleteRequested>(_onDelete);
  }

  Future<void> _onLoad(
    NotificationsLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());
    try {
      final notifications = await _repository.getFeed();
      final unread = await _repository.getUnreadCount();
      emit(
        NotificationLoaded(notifications: notifications, unreadCount: unread),
      );
    } catch (e) {
      emit(NotificationError(unwrapDioError(e)));
    }
  }

  /// Marque une ligne lue. Une ligne agrégée se lit par sa clé de groupe :
  /// toutes les notifications qu'elle recouvre passent lues d'un coup. Le
  /// compteur global décroît du nombre recouvert, pas d'une unité, parce que
  /// le serveur compte les événements et non les lignes.
  Future<void> _onMarkRead(
    NotificationMarkReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;
    NotificationModel? target;
    final updated = current.notifications.map((n) {
      if (n.id != event.id) return n;
      target = n;
      return n.copyWith(read: true);
    }).toList();
    if (target == null) return;
    final row = target!;
    final unread = row.read
        ? current.unreadCount
        : _floor(current.unreadCount - row.count);
    emit(current.copyWith(notifications: updated, unreadCount: unread));
    try {
      final groupKey = row.groupKey;
      if (row.isAggregate && groupKey != null) {
        await _repository.markGroupRead(groupKey);
      } else {
        await _repository.markRead(event.id);
      }
    } catch (_) {
      emit(current);
    }
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;
    final updated = current.notifications
        .map((n) => n.copyWith(read: true))
        .toList();
    emit(current.copyWith(notifications: updated, unreadCount: 0));
    try {
      await _repository.markAllRead();
    } catch (_) {
      emit(current);
    }
  }

  Future<void> _onDelete(
    NotificationDeleteRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;
    NotificationModel? removed;
    final optimistic = current.notifications.where((n) {
      if (n.id != event.id) return true;
      removed = n;
      return false;
    }).toList();
    final gone = removed;
    final unread = gone == null || gone.read
        ? current.unreadCount
        : _floor(current.unreadCount - gone.count);
    emit(current.copyWith(notifications: optimistic, unreadCount: unread));
    try {
      await _repository.deleteNotification(event.id);
    } catch (_) {
      emit(current);
    }
  }

  static int _floor(int n) => n < 0 ? 0 : n;
}
