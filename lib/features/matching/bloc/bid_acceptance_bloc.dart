import 'dart:async';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
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

  /// Moyen et devise de la commission du bid en cours d'acceptation.
  String _commissionMethod = AnalyticsPaymentMethod.walletBalance;
  String? _commissionCurrency;

  /// Commission d'une offre en espèces dans la famille commune
  /// `payment_succeeded` / `payment_failed` (`context: commission`). Les
  /// échecs n'étaient pas tracés, ni le succès après une 3DS.
  void _logCommission(
    String event,
    String bidId, [
    Map<String, Object> extra = const {},
  ]) {
    final currency = _commissionCurrency;
    unawaited(
      _analytics?.logEvent(
        event,
        properties: {
          'method': _commissionMethod,
          'context': AnalyticsPaymentContext.commission,
          'bid_id': bidId,
          'currency': ?currency,
          ...extra,
        },
      ),
    );
  }

  void _logAccepted(String bidId) {
    unawaited(
      _analytics?.logEvent(
        AnalyticsEvents.bidAccepted,
        properties: {'bid_id': bidId, 'method': _commissionMethod},
      ),
    );
    _logCommission(AnalyticsEvents.paymentSucceeded, bidId);
  }

  /// Acceptation refusée. Propriétés `bid_id`, `method`, `reason`,
  /// `error_code`, plus le `payment_failed` correspondant.
  void _logAcceptFailed(String bidId, String reason, String errorCode) {
    final extra = {'reason': reason, 'error_code': errorCode};
    unawaited(
      _analytics?.logEvent(
        AnalyticsEvents.bidAcceptFailed,
        properties: {'bid_id': bidId, 'method': _commissionMethod, ...extra},
      ),
    );
    _logCommission(AnalyticsEvents.paymentFailed, bidId, extra);
  }

  void _emitServerRefusal(
    Object err,
    String bidId,
    Emitter<BidAcceptanceState> emit,
  ) {
    final appErr = unwrapDioError(err);
    _logAcceptFailed(bidId, 'server_refused', appErr.code ?? 'unknown');
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
    _commissionMethod = AnalyticsPaymentMethod.walletBalance;
    _commissionCurrency = fundingCurrency;
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
    _commissionMethod = AnalyticsPaymentMethod.card;
    _commissionCurrency = null;
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
        _commissionCurrency ??= r.currency;
        emit(BidAccepted());
        _logAccepted(bidId);
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
          if (c.accepted) {
            _logAccepted(bidId);
          } else {
            _logAcceptFailed(
              bidId,
              'authentication_failed',
              'commission/confirm-failed',
            );
          }
        } on StripeException {
          _logAcceptFailed(
            bidId,
            'authentication_failed',
            'commission/3ds-interrupted',
          );
          emit(
            BidFailed(
              reason: BidFailureReason.bankAuthInterrupted,
              cardDeclined: true,
            ),
          );
        }
        return;
      case AcceptanceStatus.insufficientWallet:
        _logAcceptFailed(
          bidId,
          'insufficient_balance',
          'commission/insufficient-wallet',
        );
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
        _logAcceptFailed(bidId, 'declined', 'commission/failed');
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
