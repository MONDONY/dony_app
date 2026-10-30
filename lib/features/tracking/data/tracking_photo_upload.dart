import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

/// Issue de l'envoi de la photo d'une étape : sa clé de stockage, ou
/// [dropped] quand le serveur l'a refusée et que l'étape part sans elle, ou
/// [lost] quand le fichier local n'existe plus (cache purgé par le système,
/// réinstallation) et que l'étape part sans elle (FLUTTER-MJ).
typedef TrackingPhotoUpload = ({String? key, bool dropped, bool lost});

/// Codes par lesquels le back refuse une étape POUR L'INSTANT : la même
/// requête passera plus tard. `handover-supplement-pending` : un supplément
/// de prix attend la réponse de l'expéditeur, le scan de remise (DEPART)
/// est bloqué jusqu'à sa réponse (2 h au plus). `handover-amendment-pending` :
/// une modification attend le voyageur. `handover-sender-noshow-pending` : la
/// déclaration d'absence de l'expéditeur est contestée ou confirmée, l'équipe
/// tranche ; déclaration rejetée, le rejeu passe ; absence confirmée, il
/// reçoit un 422 `bid-not-accepted` (refus définitif).
const handoverRetryLaterCodes = {
  'handover-supplement-pending',
  'handover-amendment-pending',
  'handover-sender-noshow-pending',
};

/// Événement analytics d'une remise refusée pour l'instant, par code
/// ([handoverRetryLaterCodes]). `null` pour tout autre code.
String? handoverBlockedEvent(String? code) => switch (code) {
  'handover-supplement-pending' => AnalyticsEvents.handoverBlockedSupplement,
  'handover-amendment-pending' => AnalyticsEvents.handoverBlockedAmendment,
  'handover-sender-noshow-pending' =>
    AnalyticsEvents.handoverBlockedSenderNoShow,
  _ => null,
};

/// Vrai quand le back a refusé l'étape pour l'instant seulement
/// ([handoverRetryLaterCodes]) : la file hors ligne la garde et la renvoie
/// plus tard au lieu de la perdre.
bool isRetryLaterTrackingRejection(AppException error) =>
    error is ConflictException && handoverRetryLaterCodes.contains(error.code);

/// Vrai quand le back a refusé l'envoi pour une raison qui ne dépend pas
/// du réseau ni du moment : la même requête échouerait à l'identique. Un
/// refus « pour l'instant » ([isRetryLaterTrackingRejection]) n'en est pas un.
bool isDefinitiveTrackingRejection(AppException error) =>
    !isRetryLaterTrackingRejection(error) &&
    (error is ConflictException ||
        error is ValidationException ||
        error is NotFoundException ||
        error is ForbiddenException);

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

/// Vrai quand l'échec de lecture vient d'une photo qui n'existe vraiment
/// plus. Toute autre [FileSystemException] (fichier protégé tant que le
/// téléphone est verrouillé, sur iOS) est passagère : la photo est gardée et
/// l'envoi réessayé plus tard (FLUTTER-F).
bool isTrackingPhotoMissing(FileSystemException error, String path) {
  if (error is PathNotFoundException) return true;
  try {
    return !File(path).existsSync();
  } on FileSystemException {
    return false;
  }
}

void _warnUnreadable(FileSystemException error) => AppLog.warn(
  'tracking.photo_unreadable',
  data: {
    'type': error.runtimeType.toString(),
    'errno': ?error.osError?.errorCode,
  },
);

/// Envoie la photo de l'étape si [photoPath] existe. Une photo refusée par
/// le serveur n'empêche jamais l'étape : elle part sans photo (le scan
/// d'arrivée déclenche la capture du paiement, le perdre est grave). Une
/// photo dont le fichier local a disparu non plus ([TrackingPhotoUpload.lost]).
///
/// Panne réseau, délai, 5xx, session expirée, limite de débit, photo
/// présente mais illisible pour l'instant : l'erreur remonte et l'appelant
/// garde l'étape pour plus tard.
Future<TrackingPhotoUpload> uploadTrackingPhotoOrDrop(
  TrackingRepository repository, {
  required String bidId,
  required String? photoPath,
}) async {
  if (photoPath == null) return (key: null, dropped: false, lost: false);
  try {
    final key = await repository.uploadTrackingPhoto(bidId, photoPath);
    return (key: key, dropped: false, lost: false);
  } on FileSystemException catch (error) {
    // FLUTTER-MJ : photo locale disparue. Le back accepte toutes les étapes
    // sans photo : réessayer ne la ferait pas revenir, l'étape part sans elle.
    if (isTrackingPhotoMissing(error, photoPath)) {
      return (key: null, dropped: false, lost: true);
    }
    _warnUnreadable(error);
    rethrow;
  } catch (error) {
    // Fichier disparu pendant l'envoi : Dio enveloppe l'erreur de lecture.
    if (error is DioException && error.error is FileSystemException) {
      final inner = error.error! as FileSystemException;
      if (isTrackingPhotoMissing(inner, photoPath)) {
        return (key: null, dropped: false, lost: true);
      }
      _warnUnreadable(inner);
      rethrow;
    }
    final cause = unwrapDioError(error);
    if (isTrackingPhotoRefused(cause)) {
      return (key: null, dropped: true, lost: false);
    }
    if (isDefinitiveTrackingRejection(cause)) {
      // Refus définitif inattendu de la seule photo : l'étape part quand
      // même, et le cas reste visible dans les journaux.
      AppLog.warn(
        'tracking.photo_refused',
        data: {'type': cause.runtimeType.toString(), 'code': ?cause.code},
      );
      return (key: null, dropped: true, lost: false);
    }
    rethrow;
  }
}
