import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gère la liste des photos en cours/terminées d'upload pendant la création d'un bid.
class BidPhotosCubit extends Cubit<List<BidPhotoUpload>> {
  BidPhotosCubit(this._repository, this._analytics) : super(const []);

  final BidRepository _repository;
  final AnalyticsService _analytics;

  static const int maxPhotos = 4;
  int _counter = 0;

  bool get canAddMore => state.length < maxPhotos;

  /// Clés S3 des photos uploadées avec succès, à envoyer à la création du bid.
  List<String> get readyKeys => state
      .where(
        (p) => p.status == BidPhotoUploadStatus.ready && p.remoteKey != null,
      )
      .map((p) => p.remoteKey!)
      .toList();

  Future<void> add(String localPath) async {
    if (!canAddMore) return;
    final id = 'p${_counter++}';
    emit([...state, BidPhotoUpload(localId: id, localPath: localPath)]);
    try {
      final key = await _repository.uploadBidPhoto(localPath);
      emit([
        for (final p in state)
          if (p.localId == id)
            p.copyWith(status: BidPhotoUploadStatus.ready, remoteKey: key)
          else
            p,
      ]);
      unawaited(_analytics.logEvent(AnalyticsEvents.bidPhotoAdded));
    } catch (_) {
      emit([
        for (final p in state)
          if (p.localId == id)
            p.copyWith(status: BidPhotoUploadStatus.failed)
          else
            p,
      ]);
    }
  }

  void remove(String localId) {
    emit(state.where((p) => p.localId != localId).toList());
    unawaited(_analytics.logEvent(AnalyticsEvents.bidPhotoRemoved));
  }
}
