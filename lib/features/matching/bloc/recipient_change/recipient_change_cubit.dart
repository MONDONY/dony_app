import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class RecipientChangeState {
  const RecipientChangeState();
}

class RecipientChangeIdle extends RecipientChangeState {
  const RecipientChangeIdle();
}

class RecipientChangeSubmitting extends RecipientChangeState {
  const RecipientChangeSubmitting();
}

/// Changement accepté. [bid] porte le nouveau lien de suivi et le nouveau
/// code quand [phoneChanged] ; sinon seul le nom a changé.
class RecipientChangeSuccess extends RecipientChangeState {
  const RecipientChangeSuccess(this.bid, {required this.phoneChanged});

  final BidModel bid;
  final bool phoneChanged;
}

/// 409 : le colis a été remis entre-temps, le destinataire ne peut plus
/// changer.
class RecipientChangeConflict extends RecipientChangeState {
  const RecipientChangeConflict();
}

class RecipientChangeFailure extends RecipientChangeState {
  const RecipientChangeFailure(this.error);

  final AppException error;
}

/// Feuille « Modifier le destinataire » de la vue expéditeur
/// (`PUT /bids/{bidId}/recipient`).
class RecipientChangeCubit extends Cubit<RecipientChangeState> {
  RecipientChangeCubit(this._repository, this._analytics)
    : super(const RecipientChangeIdle());

  final BidRepository _repository;
  final AnalyticsService _analytics;

  /// Le numéro change-t-il par rapport à celui du colis ? Comparaison après
  /// normalisation, comme le serveur : « +221 77… » et « +22177… » sont le
  /// même numéro et ne renouvellent ni le lien ni le code.
  static bool isPhoneChanged(BidModel bid, String phone) =>
      normalizeRecipientPhone(bid.recipientPhone ?? '') !=
      normalizeRecipientPhone(phone);

  Future<void> submit(
    BidModel bid, {
    required String name,
    required String phone,
  }) async {
    if (state is RecipientChangeSubmitting) return;
    final normalized = normalizeRecipientPhone(phone);
    final phoneChanged = isPhoneChanged(bid, normalized);
    emit(const RecipientChangeSubmitting());
    try {
      final updated = await _repository.changeRecipient(
        bid.id,
        recipientName: name.trim(),
        recipientPhone: normalized,
      );
      if (isClosed) return;
      emit(RecipientChangeSuccess(updated, phoneChanged: phoneChanged));
      // Jamais le nom ni le numéro : seulement la nature du changement.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidRecipientChanged,
          properties: {'phone_changed': phoneChanged, 'status': bid.status},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      if (error is ConflictException) {
        emit(const RecipientChangeConflict());
        return;
      }
      emit(RecipientChangeFailure(error));
    }
  }
}
