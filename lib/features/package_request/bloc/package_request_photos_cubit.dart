import 'dart:async';
import 'dart:io';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/bloc/package_request_photo_upload.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gère les photos colis (max 4) pendant la création/édition d'une demande d'envoi.
/// Calqué sur BidPhotosCubit : upload immédiat → clé S3, exposée via [readyKeys].
class PackageRequestPhotosCubit extends Cubit<List<PackageRequestPhotoUpload>> {
  PackageRequestPhotosCubit(this._repository, this._analytics) : super(const []);

  final PackageRequestRepository _repository;
  final AnalyticsService _analytics;

  static const int maxPhotos = 4;
  int _counter = 0;

  bool get canAddMore => state.length < maxPhotos;

  /// Clés S3 des photos uploadées avec succès, à envoyer à la création/édition.
  List<String> get readyKeys => state
      .where((p) =>
          p.status == PackageRequestPhotoUploadStatus.ready && p.remoteKey != null)
      .map((p) => p.remoteKey!)
      .toList();

  /// true dès qu'au moins une photo a été ajoutée dans cette session (pour décider
  /// d'envoyer photoKeys en édition : sinon null = conserver les photos existantes).
  bool get touched => state.isNotEmpty;

  Future<void> add(String localPath) async {
    if (!canAddMore) {
      return;
    }
    final id = 'p${_counter++}';
    emit([
      ...state,
      PackageRequestPhotoUpload(localId: id, localPath: localPath),
    ]);
    try {
      final key = await _repository.uploadPhotoKey(File(localPath));
      emit([
        for (final p in state)
          if (p.localId == id)
            p.copyWith(
                status: PackageRequestPhotoUploadStatus.ready, remoteKey: key)
          else
            p,
      ]);
      unawaited(_analytics.logEvent(AnalyticsEvents.packageRequestPhotoAdded));
    } catch (e) {
      debugPrint('[PR-PHOTO] upload failed: $e');
      emit([
        for (final p in state)
          if (p.localId == id)
            p.copyWith(
                status: PackageRequestPhotoUploadStatus.failed,
                error: e.toString())
          else
            p,
      ]);
    }
  }

  void remove(String localId) {
    emit(state.where((p) => p.localId != localId).toList());
    unawaited(_analytics.logEvent(AnalyticsEvents.packageRequestPhotoRemoved));
  }
}
