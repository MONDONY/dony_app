import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'payment_event.dart';
part 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentRepository _repository;

  PaymentBloc(this._repository) : super(const PaymentInitial()) {
    on<BidCheckoutPaymentRequested>(_onBidCheckoutPaymentRequested);
    on<PaymentConnectAccountRequested>(_onConnectAccountRequested);
    on<PaymentOnboardingStatusChecked>(_onOnboardingStatusChecked);
    on<PaymentInitiated>(_onPaymentInitiated);
    on<PaymentSheetCompleted>(_onPaymentSheetCompleted);
    on<PaymentFailed>(_onPaymentFailed);
  }

  Future<void> _onBidCheckoutPaymentRequested(
    BidCheckoutPaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(CheckoutPaymentSheetReady(
      clientSecret: event.clientSecret,
      publishableKey: event.publishableKey,
      bidId: event.bidId,
    ));
  }

  Future<void> _onConnectAccountRequested(
    PaymentConnectAccountRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(const PaymentLoading());
    try {
      final account = await _repository.createConnectAccount();

      if (account.stripeOnboarded) {
        emit(const PaymentOnboardingComplete());
        return;
      }

      final link = await _repository.createOnboardingLink();
      emit(PaymentOnboardingUrlReady(link));
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onOnboardingStatusChecked(
    PaymentOnboardingStatusChecked event,
    Emitter<PaymentState> emit,
  ) async {
    emit(const PaymentLoading());
    try {
      final account = await _repository.createConnectAccount();
      if (account.stripeOnboarded) {
        emit(const PaymentOnboardingComplete());
      } else {
        emit(const PaymentOnboardingPending());
      }
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onPaymentInitiated(
    PaymentInitiated event,
    Emitter<PaymentState> emit,
  ) async {
    emit(const PaymentLoading());
    try {
      final payment = await _repository.createPayment(event.bidId);
      if (payment.clientSecret == null) {
        emit(const PaymentError('Paiement déjà effectué pour cette demande.'));
        return;
      }
      emit(PaymentSheetReady(
        clientSecret: payment.clientSecret!,
        amount: payment.amount,
        commissionAmount: payment.commissionAmount,
        paymentId: payment.id,
      ));
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onPaymentSheetCompleted(
    PaymentSheetCompleted event,
    Emitter<PaymentState> emit,
  ) async {
    final current = state;
    if (current is PaymentSheetReady) {
      emit(PaymentEscrowPending(current.amount));
    }
  }

  Future<void> _onPaymentFailed(
    PaymentFailed event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentError(event.message));
  }
}
