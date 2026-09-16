import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletRefundRequestState {
  const WalletRefundRequestState({
    this.isSubmitting = false,
    this.result,
    this.error,
  });

  final bool isSubmitting;
  final WalletRefundRequestModel? result;
  final AppException? error;

  WalletRefundRequestState copyWith({
    bool? isSubmitting,
    WalletRefundRequestModel? result,
    AppException? error,
    bool clearError = false,
  }) {
    return WalletRefundRequestState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WalletRefundRequestCubit extends Cubit<WalletRefundRequestState> {
  WalletRefundRequestCubit(this._repository, this._analytics)
    : super(const WalletRefundRequestState());

  final WalletRepository _repository;
  final AnalyticsService _analytics;

  Future<void> submit(
    String currency, [
    List<String> transactionIds = const [],
  ]) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final result = await _repository.requestRefund(currency, transactionIds);
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false, result: result));
      }
      // Tracé seulement après succès, comme depuis la suppression de compte.
      // Aucune propriété financière (ni montant ni devise).
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletRefundRequested,
          properties: const {'source': 'wallet'},
        ),
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false, error: unwrapDioError(e)));
      }
    }
  }
}
