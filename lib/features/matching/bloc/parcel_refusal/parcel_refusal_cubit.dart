import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Motif du refus d'un colis non conforme. [code] part dans l'analytics,
/// jamais le libellé ni le détail saisi.
enum ParcelRefusalReason {
  /// Contenu différent de la déclaration (ex. un téléphone déclaré en 1 kg).
  contentMismatch('content_mismatch'),

  /// Poids nettement supérieur au poids déclaré.
  overweight('overweight'),

  /// Objet interdit ou refusé sur le trajet.
  prohibited('prohibited'),

  /// Autre raison : le détail devient obligatoire.
  other('other');

  const ParcelRefusalReason(this.code);

  final String code;
}

/// Longueur maximale du motif, alignée sur le serveur
/// (`RefuseParcelRequest.reason`, `@Size(max = 500)`).
const int kParcelRefusalReasonMaxLength = 500;

enum ParcelRefusalStatus {
  editing,
  submitting,
  success,

  /// 409 : le trajet est parti entre-temps, le colis ne peut plus être refusé.
  conflict,
  failure,

  /// Photo illisible ou trop lourde : rien n'a changé dans le formulaire.
  photoFailed,
}

class ParcelRefusalState {
  const ParcelRefusalState({
    this.reason,
    this.details = '',
    this.photoPath,
    this.photoKey,
    this.status = ParcelRefusalStatus.editing,
    this.bid,
    this.error,
  });

  final ParcelRefusalReason? reason;
  final String details;

  /// Photo locale du colis, obligatoire : elle sert de preuve en cas de
  /// désaccord avec l'expéditeur.
  final String? photoPath;

  /// Clé de la photo une fois envoyée : un nouvel essai après un échec du
  /// refus ne la renvoie pas. Remise à zéro quand la photo change.
  final String? photoKey;
  final ParcelRefusalStatus status;

  /// Colis rendu par le serveur après le refus ([ParcelRefusalStatus.success]).
  final BidModel? bid;
  final AppException? error;

  bool get isSubmitting => status == ParcelRefusalStatus.submitting;

  /// Motif choisi, photo prise, et détail renseigné pour « Autre ».
  bool get canSubmit =>
      !isSubmitting &&
      reason != null &&
      photoPath != null &&
      (reason != ParcelRefusalReason.other || details.trim().isNotEmpty);

  ParcelRefusalState copyWith({
    ParcelRefusalReason? reason,
    String? details,
    String? Function()? photoPath,
    String? Function()? photoKey,
    ParcelRefusalStatus? status,
    BidModel? bid,
    AppException? error,
  }) => ParcelRefusalState(
    reason: reason ?? this.reason,
    details: details ?? this.details,
    photoPath: photoPath != null ? photoPath() : this.photoPath,
    photoKey: photoKey != null ? photoKey() : this.photoKey,
    status: status ?? ParcelRefusalStatus.editing,
    bid: bid ?? this.bid,
    error: error,
  );
}

/// Feuille « Le colis ne correspond pas » de la vue voyageur : le voyageur
/// refuse un colis non conforme à la remise, photo à l'appui
/// (`POST /bids/{bidId}/refuse-parcel`). L'expéditeur est remboursé et
/// prévenu par le serveur ; le voyageur n'est pas pénalisé.
class ParcelRefusalCubit extends Cubit<ParcelRefusalState> {
  ParcelRefusalCubit(this._repository, this._media, this._analytics)
    : super(const ParcelRefusalState());

  final BidRepository _repository;
  final DonyMediaService _media;
  final AnalyticsService _analytics;

  void selectReason(ParcelRefusalReason reason) =>
      emit(state.copyWith(reason: reason));

  void detailsChanged(String details) => emit(state.copyWith(details: details));

  Future<void> takePhoto() async {
    if (state.isSubmitting) return;
    try {
      final file = await _media.pick(source: ImageSource.camera);
      if (file == null || isClosed) return;
      emit(state.copyWith(photoPath: () => file.path, photoKey: () => null));
    } catch (e) {
      AppLog.warn('Unreadable refused-parcel photo: $e');
      if (isClosed) return;
      emit(state.copyWith(status: ParcelRefusalStatus.photoFailed));
    }
  }

  void removePhoto() =>
      emit(state.copyWith(photoPath: () => null, photoKey: () => null));

  /// Motif envoyé au serveur : le libellé du motif, suivi du détail saisi.
  /// Le libellé vient en premier car la notification de l'expéditeur ne
  /// garde que le début du texte.
  static String composeReason(String label, String details) {
    final trimmed = details.trim();
    final full = trimmed.isEmpty ? label : '$label : $trimmed';
    return full.length <= kParcelRefusalReasonMaxLength
        ? full
        : full.substring(0, kParcelRefusalReasonMaxLength);
  }

  /// [reasonLabel] : libellé du motif dans la langue de l'app, fourni par la
  /// feuille (le cubit n'a pas de contexte de traduction).
  Future<void> submit(BidModel bid, {required String reasonLabel}) async {
    if (!state.canSubmit) return;
    final reason = state.reason!;
    emit(state.copyWith(status: ParcelRefusalStatus.submitting));
    try {
      final key =
          state.photoKey ??
          await _repository.uploadRefusalPhoto(bid.id, state.photoPath!);
      if (isClosed) return;
      emit(
        state.copyWith(
          photoKey: () => key,
          status: ParcelRefusalStatus.submitting,
        ),
      );
      final refused = await _repository.refuseParcel(
        bid.id,
        reason: composeReason(reasonLabel, state.details),
        photoKey: key,
      );
      if (isClosed) return;
      emit(state.copyWith(status: ParcelRefusalStatus.success, bid: refused));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.parcelRefused,
          properties: {
            'reason': reason.code,
            'status': bid.status,
            'payment_method': bid.paymentMethod.name,
          },
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      emit(
        state.copyWith(
          status: error is ConflictException
              ? ParcelRefusalStatus.conflict
              : ParcelRefusalStatus.failure,
          error: error,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.parcelRefusalFailed,
          properties: {
            'reason': reason.code,
            'error_code': error.code ?? 'unknown',
          },
        ),
      );
    }
  }
}
