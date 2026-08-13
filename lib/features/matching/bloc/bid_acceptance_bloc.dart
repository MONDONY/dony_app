import 'dart:async';
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
  }

  Future<void> _accept(
    BidAcceptRequested e,
    Emitter<BidAcceptanceState> emit,
  ) async {
    emit(BidAccepting());
    try {
      final r = await _repo.acceptBidWithCommission(e.bidId);
      await _handleResponse(r, e.bidId, emit);
    } catch (err) {
      emit(BidFailed(err.toString()));
    }
  }

  Future<void> _acceptWithCard(
    BidAcceptWithCardRequested e,
    Emitter<BidAcceptanceState> emit,
  ) async {
    emit(BidAccepting());
    try {
      final r = await _repo.acceptBidWithCommission(
        e.bidId,
        commissionSource: 'CARD',
      );
      await _handleResponse(r, e.bidId, emit);
    } catch (err) {
      emit(BidFailed(err.toString()));
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
                    c.error ?? 'Confirmation échouée',
                    cardDeclined: true,
                  ),
          );
        } on StripeException {
          emit(
            BidFailed(
              'Authentification bancaire interrompue',
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
          ),
        );
        return;
      case AcceptanceStatus.failed:
        emit(BidFailed(r.error ?? 'Acceptation refusée', cardDeclined: true));
        return;
    }
  }
}
