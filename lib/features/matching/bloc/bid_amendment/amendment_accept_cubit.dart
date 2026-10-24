import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/supplement_commission_unfunded.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AmendmentAcceptStatus {
  idle,
  accepting,

  /// Espèces : 3DS de la commission en cours.
  commissionAuth,
  accepted,

  /// Stripe traite encore la commission : le webhook tranchera.
  pending,

  /// Espèces : le solde ne couvre pas la commission, rien n'est accepté.
  unfunded,
  failure,
}

class AmendmentAcceptState {
  const AmendmentAcceptState({
    this.status = AmendmentAcceptStatus.idle,
    this.amendment,
    this.unfunded,
    this.error,
  });

  final AmendmentAcceptStatus status;

  /// Dernière vue de la modification rendue par le serveur.
  final BidAmendment? amendment;
  final SupplementCommissionUnfunded? unfunded;

  /// Erreur de l'API ; `null` pour une 3DS abandonnée.
  final AppException? error;

  bool get isBusy =>
      status == AmendmentAcceptStatus.accepting ||
      status == AmendmentAcceptStatus.commissionAuth;
}

/// Le voyageur accepte une modification de colis. Carte : capture du montant
/// de l'expéditeur côté serveur. Espèces : commission prélevée sur son solde
/// ou sa carte (3DS possible). Après [AmendmentAcceptStatus.accepted], l'encart
/// fait relire le colis.
class AmendmentAcceptCubit extends Cubit<AmendmentAcceptState> {
  AmendmentAcceptCubit(this._repository, this._analytics, this._flow)
    : super(const AmendmentAcceptState());

  final BidAmendmentRepository _repository;
  final AnalyticsService _analytics;
  final AmendmentCommissionFlow _flow;

  Future<void> accept(
    BidModel bid,
    BidAmendment a, {
    SupplementCommissionSource? source,
    String? fundingCurrency,
  }) {
    final cash = a.isCash;
    final commissionSource = cash
        ? (source ?? SupplementCommissionSource.wallet)
        : null;
    final funding =
        cash && commissionSource == SupplementCommissionSource.wallet
        ? fundingCurrency
        : null;
    return _run(
      bid,
      a,
      commissionSource: commissionSource,
      funding: funding,
      action: 'accept',
      call: () => _repository.accept(
        bid.id,
        a.id,
        commissionSource: commissionSource,
        fundingCurrency: funding,
      ),
    );
  }

  /// Reprise d'une modification restée en `COMMISSION_PENDING` (3DS abandonnée) :
  /// `…/commission/confirm` puis la 3DS si la carte la redemande, jamais un
  /// nouvel `accept`.
  Future<void> resume(BidModel bid, BidAmendment a) => _run(
    bid,
    a,
    commissionSource: SupplementCommissionSource.card,
    funding: null,
    action: 'confirm_commission',
    call: () => _repository.confirmCommission(bid.id, a.id),
  );

  Future<void> _run(
    BidModel bid,
    BidAmendment a, {
    required SupplementCommissionSource? commissionSource,
    required String? funding,
    required String action,
    required Future<BidAmendment> Function() call,
  }) async {
    if (state.isBusy) return;
    final cash = a.isCash;
    emit(const AmendmentAcceptState(status: AmendmentAcceptStatus.accepting));
    try {
      var result = await call();
      if (result.needsCommissionAuth) {
        if (isClosed) return;
        emit(
          AmendmentAcceptState(
            status: AmendmentAcceptStatus.commissionAuth,
            amendment: result,
          ),
        );
        result = await _flow.settle(bid.id, result);
      }
      // Acquise, ou en attente du dépôt mobile money : le serveur a tranché.
      // Sinon Stripe traite encore la commission, le webhook décidera.
      final settled =
          result.status.isSecured ||
          result.status == BidAmendmentStatus.paymentPending;
      if (settled) {
        if (cash) _flow.logCharged(result, commissionSource!);
        if (funding != null) {
          unawaited(
            _analytics.logEvent(
              AnalyticsEvents.commissionFundingCurrencyChosen,
              properties: {
                'currency': funding,
                'context': AnalyticsPaymentContext.bidAmendment,
              },
            ),
          );
        }
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.bidAmendmentAccepted,
            properties: {
              'method': amendmentMethodOf(a),
              'commission_source': ?commissionSource?.analyticsValue,
            },
          ),
        );
      }
      if (isClosed) return;
      emit(
        AmendmentAcceptState(
          status: settled
              ? AmendmentAcceptStatus.accepted
              : AmendmentAcceptStatus.pending,
          amendment: result,
        ),
      );
    } on AmendmentCommissionAuthInterrupted {
      _flow.logFailed(
        commissionSource ?? SupplementCommissionSource.card,
        reason: 'authentication_failed',
        errorCode: 'commission/3ds-interrupted',
      );
      _logFailed(action, 'commission/3ds-interrupted');
      if (isClosed) return;
      emit(const AmendmentAcceptState(status: AmendmentAcceptStatus.failure));
    } catch (e) {
      final error = unwrapDioError(e);
      final code = error.code ?? 'unknown';
      final unfunded = SupplementCommissionUnfunded.fromError(error);
      if (unfunded != null) {
        _flow.logFailed(
          commissionSource ?? SupplementCommissionSource.wallet,
          reason: 'insufficient_balance',
          errorCode: code,
          currency: unfunded.currency,
        );
      }
      _logFailed(action, code);
      if (isClosed) return;
      emit(
        AmendmentAcceptState(
          status: unfunded != null
              ? AmendmentAcceptStatus.unfunded
              : AmendmentAcceptStatus.failure,
          unfunded: unfunded,
          error: error,
        ),
      );
    }
  }

  void _logFailed(String action, String code) => unawaited(
    _analytics.logEvent(
      AnalyticsEvents.bidAmendmentActionFailed,
      properties: {'action': action, 'error_code': code},
    ),
  );
}
