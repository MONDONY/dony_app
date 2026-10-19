import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SupplementCommissionResumeStatus {
  idle,

  /// Vérification locale (`requirePaymentAuth`) ouverte : le bouton est
  /// désactivé, un double tap n'ouvre pas une seconde invite.
  authorizing,

  /// Confirmation (et 3DS) en cours.
  busy,

  /// Commission prélevée : la demande est partie chez l'expéditeur.
  proposed,

  /// Stripe traite encore le débit : le webhook tranchera.
  pending,

  /// 3DS abandonnée, carte refusée ou réseau : l'encart relit le colis.
  failure,
}

class SupplementCommissionResumeState {
  const SupplementCommissionResumeState({
    this.status = SupplementCommissionResumeStatus.idle,
    this.error,
  });

  final SupplementCommissionResumeStatus status;

  /// Erreur de l'API ; `null` pour une 3DS abandonnée.
  final AppException? error;

  bool get isBusy =>
      status == SupplementCommissionResumeStatus.authorizing ||
      status == SupplementCommissionResumeStatus.busy;
}

/// Encart du voyageur, colis payé en espèces : « Valider le paiement » d'une
/// demande de supplément restée en `COMMISSION_PENDING` (3DS abandonnée,
/// application fermée, débit resté sans réponse). Passe par
/// `…/commission/confirm` puis la 3DS si la carte la redemande, jamais par un
/// nouveau `POST`. L'écran pose [beginAuthorization] et `requirePaymentAuth`
/// avant [resume] : la reprise peut débiter la carte.
class SupplementCommissionCubit extends Cubit<SupplementCommissionResumeState> {
  SupplementCommissionCubit(this._flow, this._analytics)
    : super(const SupplementCommissionResumeState());

  final SupplementCommissionFlow _flow;
  final AnalyticsService _analytics;

  bool beginAuthorization() {
    if (isClosed || state.isBusy) return false;
    emit(
      const SupplementCommissionResumeState(
        status: SupplementCommissionResumeStatus.authorizing,
      ),
    );
    return true;
  }

  void authorizationDenied() {
    if (isClosed ||
        state.status != SupplementCommissionResumeStatus.authorizing) {
      return;
    }
    emit(const SupplementCommissionResumeState());
  }

  Future<void> resume(BidModel bid, BidSupplement supplement) async {
    if (isClosed || state.status == SupplementCommissionResumeStatus.busy) {
      return;
    }
    emit(
      const SupplementCommissionResumeState(
        status: SupplementCommissionResumeStatus.busy,
      ),
    );
    const source = SupplementCommissionSource.card;
    try {
      final settled = await _flow.resume(bid.id, supplement.id);
      final stillPending =
          settled.status == BidSupplementStatus.commissionPending;
      if (!stillPending) _flow.logCharged(settled, source);
      _logOutcome(stillPending ? 'pending' : 'proposed');
      if (isClosed) return;
      emit(
        SupplementCommissionResumeState(
          status: stillPending
              ? SupplementCommissionResumeStatus.pending
              : SupplementCommissionResumeStatus.proposed,
        ),
      );
    } on SupplementCommissionAuthInterrupted {
      _flow.logFailed(
        source,
        reason: 'authentication_failed',
        errorCode: 'commission/3ds-interrupted',
      );
      _logOutcome('failed');
      if (isClosed) return;
      emit(
        const SupplementCommissionResumeState(
          status: SupplementCommissionResumeStatus.failure,
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      _flow.logFailed(
        source,
        reason: error.code == 'supplement-commission-card-declined'
            ? 'declined'
            : 'generic',
        errorCode: error.code ?? 'unknown',
      );
      _logOutcome('failed');
      if (isClosed) return;
      emit(
        SupplementCommissionResumeState(
          status: SupplementCommissionResumeStatus.failure,
          error: error,
        ),
      );
    }
  }

  void _logOutcome(String outcome) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bidSupplementCommissionResumed,
        properties: {'outcome': outcome},
      ),
    );
  }
}
