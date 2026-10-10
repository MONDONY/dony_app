import 'dart:async';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class BidAcceptanceBloc extends Bloc<BidAcceptanceEvent, BidAcceptanceState> {
  final BidRepository _repo;
  final Stripe _stripe;
  final AnalyticsService? _analytics;

  BidAcceptanceBloc(this._repo, this._stripe, [this._analytics])
    : super(BidAcceptanceInitial()) {
    on<BidAcceptRequested>(_accept);
    on<BidAcceptWithCardRequested>(_acceptWithCard);
    on<BidAcceptanceRefusalsCleared>((_, _) => _refusals.clear());
  }

  /// Codes d'un refus qui se répéterait à l'identique tant que la demande ou
  /// le trajet ne changent pas. Staging 10/10 : sept 409
  /// `capacity-insufficient` de suite sur la même demande, chaque tap
  /// affichant « Acceptation refusée ».
  static const definitiveRefusalCodes = <String>{
    'capacity-insufficient',
    'announcement-not-accepting',
    'announcement-not-found',
    'bid-not-found',
    'invalid-payment-method-for-announcement',
    'handover-deadline-passed',
    'forbidden',
  };

  /// Refus définitifs par demande : un nouveau tap rejoue le message sans
  /// rappeler le serveur.
  final Map<String, AppException> _refusals = {};

  /// Demandes dont l'acceptation est refusée pour de bon, avec l'erreur.
  Map<String, AppException> get refusals => Map.unmodifiable(_refusals);

  /// Rejoue le refus mémorisé de [bidId] ; `false` s'il n'y en a pas.
  bool _replayRefusal(String bidId, Emitter<BidAcceptanceState> emit) {
    final known = _refusals[bidId];
    if (known == null) return false;
    emit(
      BidFailed(
        reason: BidFailureReason.refused,
        error: known,
        bidId: bidId,
        definitive: true,
      ),
    );
    return true;
  }

  void _emitServerRefusal(
    Object err,
    String bidId,
    Emitter<BidAcceptanceState> emit,
  ) {
    final appErr = unwrapDioError(err);
    final definitive = definitiveRefusalCodes.contains(appErr.code);
    if (definitive) _refusals[bidId] = appErr;
    emit(
      BidFailed(
        reason: BidFailureReason.refused,
        error: appErr,
        bidId: bidId,
        definitive: definitive,
      ),
    );
  }

  Future<void> _accept(
    BidAcceptRequested e,
    Emitter<BidAcceptanceState> emit,
  ) async {
    if (_replayRefusal(e.bidId, emit)) return;
    emit(BidAccepting());
    final fundingCurrency = e.fundingCurrency;
    if (fundingCurrency != null) {
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.commissionFundingCurrencyChosen,
          properties: {'currency': fundingCurrency, 'context': 'bid'},
        ),
      );
    }
    try {
      final r = await _repo.acceptBidWithCommission(
        e.bidId,
        fundingCurrency: fundingCurrency,
      );
      await _handleResponse(r, e.bidId, emit);
    } catch (err) {
      // AppException.message n'est jamais un texte affichable (voir sa doc) :
      // serverMessage reste vide ; displayMessage() lit le message du
      // catalogue pour le code de l'erreur, sinon la clé de
      // BidFailureReason.refused.
      _emitServerRefusal(err, e.bidId, emit);
    }
  }

  Future<void> _acceptWithCard(
    BidAcceptWithCardRequested e,
    Emitter<BidAcceptanceState> emit,
  ) async {
    if (_replayRefusal(e.bidId, emit)) return;
    emit(BidAccepting());
    try {
      final r = await _repo.acceptBidWithCommission(
        e.bidId,
        commissionSource: 'CARD',
      );
      await _handleResponse(r, e.bidId, emit);
    } catch (err) {
      // Même raison qu'en haut : pas de message serveur affichable ici.
      _emitServerRefusal(err, e.bidId, emit);
    }
  }

  Future<void> _handleResponse(
    AcceptanceResponse r,
    String bidId,
    Emitter<BidAcceptanceState> emit,
  ) async {
    switch (r.status) {
      case AcceptanceStatus.accepted:
        emit(BidAccepted());
        unawaited(
          _analytics?.logEvent(
            AnalyticsEvents.bidAccepted,
            properties: {'bid_id': bidId},
          ),
        );
        return;
      case AcceptanceStatus.requires3ds:
        try {
          await _stripe.handleNextAction(r.clientSecret!);
          final c = await _repo.confirmCommissionAcceptance(bidId);
          emit(
            c.accepted
                ? BidAccepted()
                : BidFailed(
                    serverMessage: c.error,
                    reason: BidFailureReason.confirmFailed,
                    cardDeclined: true,
                  ),
          );
        } on StripeException {
          emit(
            BidFailed(
              reason: BidFailureReason.bankAuthInterrupted,
              cardDeclined: true,
            ),
          );
        }
        return;
      case AcceptanceStatus.insufficientWallet:
        emit(
          BidWalletInsufficient(
            availableBalance: r.availableBalance ?? 0,
            requiredCommission: r.requiredCommission ?? 0,
            hasCard: r.hasCard ?? false,
            bidId: bidId,
            currency: r.currency,
            breakdown: r.breakdown,
            bidCurrency: r.bidCurrency,
            alternatives: r.alternatives,
          ),
        );
        return;
      case AcceptanceStatus.failed:
        emit(
          BidFailed(
            serverMessage: r.error,
            reason: BidFailureReason.refused,
            cardDeclined: true,
          ),
        );
        return;
    }
  }
}
