import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_event.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_state.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La boîte « Annonces Yadony » : la liste des annonces plateforme, servie par
/// `GET /notifications/annonces`, jamais mêlée au feed.
class AnnouncementsInboxBloc
    extends Bloc<AnnouncementsInboxEvent, AnnouncementsInboxState> {
  final NotificationRepository _repository;
  final AnalyticsService _analytics;

  AnnouncementsInboxBloc(this._repository, this._analytics)
    : super(const AnnouncementsInboxInitial()) {
    on<AnnouncementsInboxLoadRequested>(_onLoad);
    on<AnnouncementsInboxMarkReadRequested>(_onMarkRead);
  }

  Future<void> _onLoad(
    AnnouncementsInboxLoadRequested event,
    Emitter<AnnouncementsInboxState> emit,
  ) async {
    emit(const AnnouncementsInboxLoading());
    try {
      final announcements = await _repository.getAnnouncements();
      final loaded = AnnouncementsInboxLoaded(announcements);
      emit(loaded);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.announcementsInboxOpened,
          properties: {
            'count': announcements.length,
            'unread': loaded.unreadCount,
          },
        ),
      );
    } catch (e) {
      emit(AnnouncementsInboxError(unwrapDioError(e)));
    }
  }

  Future<void> _onMarkRead(
    AnnouncementsInboxMarkReadRequested event,
    Emitter<AnnouncementsInboxState> emit,
  ) async {
    final current = state;
    if (current is! AnnouncementsInboxLoaded) return;
    final target = current.announcements
        .where((a) => a.id == event.id)
        .firstOrNull;
    if (target == null || target.read) return;
    emit(
      AnnouncementsInboxLoaded(
        current.announcements
            .map((a) => a.id == event.id ? a.copyWith(read: true) : a)
            .toList(),
      ),
    );
    try {
      await _repository.markRead(event.id);
    } catch (_) {
      emit(current);
    }
  }
}
