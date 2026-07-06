import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class IncidentReportState {}

class IncidentReportInitial extends IncidentReportState {}

class IncidentReportSubmitting extends IncidentReportState {}

class IncidentReportSuccess extends IncidentReportState {
  final String reportId;
  IncidentReportSuccess(this.reportId);
}

class IncidentReportError extends IncidentReportState {
  final String message;
  IncidentReportError(this.message);
}

/// Soumission d'un signalement d'incident.
class IncidentReportCubit extends Cubit<IncidentReportState> {
  IncidentReportCubit(this._repository, this._analytics)
      : super(IncidentReportInitial());

  final IncidentReportRepository _repository;
  final AnalyticsService _analytics;

  Future<void> submit({
    required IncidentTargetType targetType,
    String? targetId,
    required String reason,
    String? description,
    List<String> photoKeys = const [],
  }) async {
    if (state is IncidentReportSubmitting) {
      return;
    }
    emit(IncidentReportSubmitting());
    try {
      final id = await _repository.submit(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        description: description,
        photoKeys: photoKeys,
      );
      unawaited(_analytics.logEvent(
        AnalyticsEvents.incidentReported,
        properties: {'target_type': targetType.apiValue, 'photo_count': photoKeys.length},
      ));
      emit(IncidentReportSuccess(id));
    } on AppException catch (e) {
      emit(IncidentReportError(e.message));
    } catch (_) {
      emit(IncidentReportError('Impossible d\'envoyer le signalement. Réessayez.'));
    }
  }
}
