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
      final notifications = await _repository.getNotifications();
      final unread = await _repository.getUnreadCount();
      emit(NotificationLoaded(notifications: notifications, unreadCount: unread));
    } catch (_) {
      emit(const NotificationError('Impossible de charger les notifications'));
    }
  }

  Future<void> _onMarkRead(
    NotificationMarkReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;
    try {
      await _repository.markRead(event.id);
      final updated = current.notifications.map((n) {
        return n.id == event.id ? _setRead(n) : n;
      }).toList();
      final unread = updated.where((n) => !n.read).length;
      emit(current.copyWith(notifications: updated, unreadCount: unread));
    } catch (_) {}
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;
    try {
      await _repository.markAllRead();
      final updated = current.notifications.map(_setRead).toList();
      emit(current.copyWith(notifications: updated, unreadCount: 0));
    } catch (_) {}
  }

  Future<void> _onDelete(
    NotificationDeleteRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;
    final optimistic = current.notifications.where((n) => n.id != event.id).toList();
    final unread = optimistic.where((n) => !n.read).length;
    emit(current.copyWith(notifications: optimistic, unreadCount: unread));
    try {
      await _repository.deleteNotification(event.id);
    } catch (_) {
      emit(current);
    }
  }

  NotificationModel _setRead(NotificationModel n) {
    return NotificationModel(
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      data: n.data,
      read: true,
      createdAt: n.createdAt,
    );
  }
}
