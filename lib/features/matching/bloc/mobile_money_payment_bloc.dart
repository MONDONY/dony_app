import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';

class MobileMoneyPaymentBloc
    extends Bloc<MobileMoneyPaymentEvent, MobileMoneyPaymentState> {
  MobileMoneyPaymentBloc(this._repository)
    : super(const MobileMoneyPaymentInitial()) {
    on<MobileMoneyStatusPolled>(_onStatusPolled);
    on<MobileMoneyLinkRegenRequested>(_onLinkRegen);
  }

  final MobileMoneyRepository _repository;

  Future<void> _onStatusPolled(
    MobileMoneyStatusPolled event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    // Emit Loading only on the first call (Initial or Error state).
    // Periodic polls silently refresh to avoid flashing a full-screen spinner
    // over the PENDING content + "Payer maintenant" button.
    if (state is MobileMoneyPaymentInitial ||
        state is MobileMoneyPaymentError) {
      emit(const MobileMoneyPaymentLoading());
    }
    try {
      final model = await _repository.getStatus(event.bidId);
      switch (model.status) {
        case 'COMPLETED':
          emit(const MobileMoneyPaymentConfirmed());
        case 'EXPIRED':
          emit(const MobileMoneyPaymentExpired());
        case 'FAILED':
          emit(
            MobileMoneyPaymentError(model.failureReason ?? 'Paiement échoué'),
          );
        default:
          emit(
            MobileMoneyPaymentPending(
              paymentLink: model.paymentLink ?? '',
              expiresAt: model.expiresAt,
            ),
          );
      }
    } catch (e) {
      emit(MobileMoneyPaymentError(e.toString()));
    }
  }

  Future<void> _onLinkRegen(
    MobileMoneyLinkRegenRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    emit(const MobileMoneyPaymentLoading());
    try {
      final model = await _repository.regenerateLink(event.bidId);
      emit(
        MobileMoneyPaymentPending(
          paymentLink: model.paymentLink ?? '',
          expiresAt: model.expiresAt,
        ),
      );
    } catch (e) {
      emit(MobileMoneyPaymentError(e.toString()));
    }
  }
}
