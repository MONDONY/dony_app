import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class BidAcceptanceBloc extends Bloc<BidAcceptanceEvent, BidAcceptanceState> {
  final BidRepository _repo;
  final Stripe _stripe;

  BidAcceptanceBloc(this._repo, this._stripe) : super(BidAcceptanceInitial()) {
    on<BidAcceptRequested>(_accept);
  }

  Future<void> _accept(
      BidAcceptRequested e, Emitter<BidAcceptanceState> emit) async {
    emit(BidAccepting());
    try {
      final r = await _repo.acceptBidWithCommission(e.bidId);
      switch (r.status) {
        case AcceptanceStatus.accepted:
          emit(BidAccepted());
          return;
        case AcceptanceStatus.requires3ds:
          try {
            await _stripe.handleNextAction(r.clientSecret!);
            final c = await _repo.confirmCommissionAcceptance(e.bidId);
            emit(c.accepted
                ? BidAccepted()
                : BidFailed(c.error ?? 'Confirmation échouée'));
          } on StripeException {
            emit(BidFailed('Authentification bancaire interrompue'));
          }
          return;
        case AcceptanceStatus.failed:
          emit(BidFailed(r.error ?? 'Acceptation refusée'));
          return;
      }
    } catch (err) {
      emit(BidFailed(err.toString()));
    }
  }
}
