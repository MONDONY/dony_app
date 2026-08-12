import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/incident_report/bloc/incident_photo_upload.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gère la liste des captures d'écran en cours/terminées d'upload
/// pendant la rédaction d'un signalement. Max 4.
class IncidentPhotosCubit extends Cubit<List<IncidentPhotoUpload>> {
  IncidentPhotosCubit(this._repository, this._analytics) : super(const []);

  final IncidentReportRepository _repository;
  final AnalyticsService _analytics;

  static const int maxPhotos = 4;
  int _counter = 0;

  bool get canAddMore => state.length < maxPhotos;

  /// Clés S3 des captures uploadées avec succès, à joindre au signalement.
  List<String> get readyKeys => state
      .where(
        (p) =>
            p.status == IncidentPhotoUploadStatus.ready && p.remoteKey != null,
      )
      .map((p) => p.remoteKey!)
      .toList();

  /// Vrai tant qu'au moins un upload est en cours (bloque l'envoi).
  bool get hasUploading =>
      state.any((p) => p.status == IncidentPhotoUploadStatus.uploading);

  Future<void> add(String localPath) async {
    if (!canAddMore) {
      return;
    }
    final id = 'p${_counter++}';
    emit([...state, IncidentPhotoUpload(localId: id, localPath: localPath)]);
    try {
      final key = await _repository.uploadPhoto(localPath);
      emit([
        for (final p in state)
          if (p.localId == id)
            p.copyWith(status: IncidentPhotoUploadStatus.ready, remoteKey: key)
          else
            p,
      ]);
      unawaited(_analytics.logEvent(AnalyticsEvents.incidentPhotoAdded));
    } catch (_) {
      emit([
        for (final p in state)
          if (p.localId == id)
            p.copyWith(status: IncidentPhotoUploadStatus.failed)
          else
            p,
      ]);
    }
  }

  void remove(String localId) {
    emit(state.where((p) => p.localId != localId).toList());
  }
}
