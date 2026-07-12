import 'dart:async';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'payment_event.dart';
part 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentRepository _repository;
  final AnalyticsService _analytics;

  PaymentBloc(this._repository, this._analytics) : super(const PaymentInitial()) {
    on<BidCheckoutPaymentRequested>(_onBidCheckoutPaymentRequested);
    on<PaymentConnectAccountRequested>(_onConnectAccountRequested);
    on<PaymentOnboardingStatusChecked>(_onOnboardingStatusChecked);
    on<PaymentOnboardingRefreshRequested>(_onOnboardingRefreshRequested);
    on<PaymentInitiated>(_onPaymentInitiated);
    on<PaymentSheetCompleted>(_onPaymentSheetCompleted);
    on<PaymentFailed>(_onPaymentFailed);
  }

  Future<void> _onBidCheckoutPaymentRequested(
    BidCheckoutPaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    // Transition intermédiaire obligatoire : si le backend renvoie le même
    // clientSecret (idempotency sur un PI encore en requires_payment_method),
    // le nouvel état serait Equatable-égal au précédent et emit() serait un
    // no-op silencieux. L'état initial garantit la transition.
    emit(const PaymentInitial());
    emit(CheckoutPaymentSheetReady(
      clientSecret: event.clientSecret,
      publishableKey: event.publishableKey,
      bidId: event.bidId,
      amountEur: event.amountEur,
      paymentMethodTypes: event.paymentMethodTypes,
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
      emit(PaymentError(unwrapDioError(e)));
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
      emit(PaymentError(unwrapDioError(e)));
    }
  }

  Future<void> _onOnboardingRefreshRequested(
    PaymentOnboardingRefreshRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(const PaymentLoading());
    try {
      final account = await _repository.refreshConnectAccount();
      if (account.stripeOnboarded) {
        emit(const PaymentOnboardingComplete());
      } else {
        emit(const PaymentOnboardingPending());
      }
    } catch (e) {
      emit(PaymentError(unwrapDioError(e)));
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
        emit(PaymentError(NetworkException(
          'Paiement déjà effectué pour cette demande.',
          code: 'payment-already-done',
        )));
        return;
      }
      emit(PaymentSheetReady(
        clientSecret: payment.clientSecret!,
        amount: payment.amount,
        commissionAmount: payment.commissionAmount,
        paymentId: payment.id,
      ));
    } catch (e) {
      emit(PaymentError(unwrapDioError(e)));
    }
  }

  Future<void> _onPaymentSheetCompleted(
    PaymentSheetCompleted event,
    Emitter<PaymentState> emit,
  ) async {
    final current = state;
    if (current is PaymentSheetReady) {
      emit(PaymentEscrowPending(current.amount));
      unawaited(_analytics.logEvent(
        AnalyticsEvents.paymentSucceeded,
        properties: {
          'method': 'card',
          'amount': current.amount,
          'payment_id': current.paymentId,
        },
      ));
    }
  }

  Future<void> _onPaymentFailed(
    PaymentFailed event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentError(NetworkException(event.message, code: 'payment-failed')));
    unawaited(_analytics.logEvent(
      AnalyticsEvents.paymentFailed,
      properties: {'method': 'card', 'error_code': 'payment-failed'},
    ));
  }
}
