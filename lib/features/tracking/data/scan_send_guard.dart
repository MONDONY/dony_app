import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

/// Un seul envoi à la fois par étape d'un colis (colis + type), toutes
/// sources confondues : entrée de la file hors ligne, validation de l'onglet
/// Suivi, envoi direct du parcours photo.
///
/// FLUTTER-JV : le même DEPART partait deux fois à 0,5 s d'écart (envoi
/// direct + file hors ligne), et le second prenait un 500 côté back (index
/// unique uq_tracking_one_depart_per_bid). Désormais, un second envoi de la
/// même étape attend le premier et rend son évènement.
///
/// Un « déjà enregistré » du back est un succès : 200 idempotent du back
/// corrigé, ou 409 [alreadyRecordedCodes] d'un back plus ancien.
class ScanSendGuard {
  ScanSendGuard({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Partagé par la file, l'onglet Suivi et l'envoi direct.
  static final shared = ScanSendGuard();

  final DateTime Function() _now;
  final _sending = <String, Future<TrackingEventModel>>{};

  /// Codes 409 par lesquels le back dit que l'étape existe déjà.
  static const alreadyRecordedCodes = {
    'depart-already-scanned',
    'scan-already-recorded',
  };

  static bool isAlreadyRecorded(AppException error) =>
      error is ConflictException && alreadyRecordedCodes.contains(error.code);

  static String _key(String bidId, String eventType) => '$bidId|$eventType';

  /// `true` pendant l'envoi de cette étape de ce colis.
  bool isSending(String bidId, String eventType) =>
      _sending.containsKey(_key(bidId, eventType));

  /// Envoie l'étape par [post], sauf si la même part déjà : on attend alors
  /// son issue et on rend son évènement. Si ce premier envoi échoue, celui-ci
  /// tente à son tour. Sur un 409 « déjà enregistré », l'étape est relue par
  /// [repository] (à défaut, une étape locale suffit : l'écran n'en lit que
  /// le type).
  Future<TrackingEventModel> postStepOnce({
    required String bidId,
    required String eventType,
    required Future<TrackingEventModel> Function() post,
    TrackingRepository? repository,
  }) async {
    final key = _key(bidId, eventType);
    for (;;) {
      final running = _sending[key];
      if (running == null) break;
      try {
        return await running;
      } catch (_) {
        // Le premier envoi a échoué : celui-ci tente à son tour.
        if (identical(_sending[key], running)) _sending.remove(key)?.ignore();
      }
    }
    final sending = _postTolerant(bidId, eventType, post, repository);
    _sending[key] = sending;
    try {
      return await sending;
    } finally {
      if (identical(_sending[key], sending)) _sending.remove(key)?.ignore();
    }
  }

  Future<TrackingEventModel> _postTolerant(
    String bidId,
    String eventType,
    Future<TrackingEventModel> Function() post,
    TrackingRepository? repository,
  ) async {
    try {
      return await post();
    } catch (error) {
      if (!isAlreadyRecorded(unwrapDioError(error))) rethrow;
      return _recordedStep(bidId, eventType, repository);
    }
  }

  Future<TrackingEventModel> _recordedStep(
    String bidId,
    String eventType,
    TrackingRepository? repository,
  ) async {
    if (repository != null) {
      try {
        for (final event in await repository.getEvents(bidId)) {
          if (event.eventType == eventType) return event;
        }
      } catch (_) {
        // Relecture facultative : l'étape est enregistrée de toute façon.
      }
    }
    final now = _now();
    return TrackingEventModel(
      id: '',
      bidId: bidId,
      eventType: eventType,
      scannedAt: now,
      createdAt: now,
    );
  }
}
