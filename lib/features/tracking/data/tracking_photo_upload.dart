import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

/// Issue de l'envoi de la photo d'une étape : sa clé de stockage, ou
/// [dropped] quand le serveur l'a refusée et que l'étape part sans elle.
typedef TrackingPhotoUpload = ({String? key, bool dropped});

/// Codes par lesquels le serveur refuse la photo elle-même : la renvoyer
/// échouerait à l'identique.
const trackingPhotoRefusalCodes = {
  'tracking-photo-limit-reached',
  // Le back exempte le suivi du quota journalier ; s'il arrive quand même,
  // mieux vaut poster sans photo que boucler à chaque synchronisation.
  'photo-upload-quota-exceeded',
  'file-too-large',
  'image/too-large',
};

/// Vrai quand le serveur a refusé la photo de suivi pour une raison connue
/// (limite du colis, quota, fichier ou image trop gros).
bool isTrackingPhotoRefused(AppException error) => switch (error) {
  RateLimitException(:final apiCode) => trackingPhotoRefusalCodes.contains(
    apiCode,
  ),
  ValidationException(:final code) => trackingPhotoRefusalCodes.contains(code),
  _ => false,
};

/// Envoie la photo de l'étape si [photoPath] existe. Une photo refusée par
/// le serveur n'empêche jamais l'étape : elle part sans photo (le scan
/// d'arrivée déclenche la capture du paiement, le perdre est grave).
///
/// Panne réseau, délai, 5xx, session expirée, limite de débit : l'erreur
/// remonte et l'appelant garde l'étape pour plus tard.
Future<TrackingPhotoUpload> uploadTrackingPhotoOrDrop(
  TrackingRepository repository, {
  required String bidId,
  required String? photoPath,
}) async {
  if (photoPath == null) return (key: null, dropped: false);
  try {
    final key = await repository.uploadTrackingPhoto(bidId, photoPath);
    return (key: key, dropped: false);
  } catch (error) {
    final cause = unwrapDioError(error);
    if (isTrackingPhotoRefused(cause)) return (key: null, dropped: true);
    if (OfflineSyncService.isDefinitiveRejection(cause)) {
      // Refus définitif inattendu de la seule photo : l'étape part quand
      // même, et le cas reste visible dans les journaux.
      AppLog.warn(
        'tracking.photo_refused',
        data: {'type': cause.runtimeType.toString(), 'code': ?cause.code},
      );
      return (key: null, dropped: true);
    }
    rethrow;
  }
}
