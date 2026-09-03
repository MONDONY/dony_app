import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/notifications/data/notification_detail.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class NotificationDetailState {
  const NotificationDetailState();
}

class NotificationDetailLoading extends NotificationDetailState {
  const NotificationDetailLoading();
}

class NotificationDetailLoaded extends NotificationDetailState {
  final NotificationDetail detail;
  const NotificationDetailLoaded(this.detail);
}

class NotificationDetailError extends NotificationDetailState {
  final AppException error;
  const NotificationDetailError(this.error);
}

/// L'écran de détail générique : une notification et son texte complet.
/// Réservé aux lignes sans deeplink (les annonces plateforme) ; la ligne est
/// marquée lue ici aussi, pour le cas où l'écran s'ouvre sans passer par le
/// sheet (retour arrière, lien).
class NotificationDetailCubit extends Cubit<NotificationDetailState> {
  NotificationDetailCubit(this._repository, this._analytics)
    : super(const NotificationDetailLoading());

  final NotificationRepository _repository;
  final AnalyticsService _analytics;

  Future<void> load(String id) async {
    emit(const NotificationDetailLoading());
    try {
      final detail = await _repository.getDetail(id);
      emit(NotificationDetailLoaded(detail));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.notificationDetailOpened,
          properties: {'type': detail.type, 'category': detail.category},
        ),
      );
      if (!detail.read) {
        // La lecture ne conditionne pas l'affichage : un échec passe.
        unawaited(_repository.markRead(id).catchError((_) {}));
      }
    } catch (e) {
      emit(NotificationDetailError(unwrapDioError(e)));
    }
  }
}
