import 'package:dony/core/error/app_exception.dart';
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
  WalletRefundRequestCubit(this._repository)
    : super(const WalletRefundRequestState());

  final WalletRepository _repository;

  Future<void> submit(String currency) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final result = await _repository.requestRefund(currency);
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false, result: result));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false, error: unwrapDioError(e)));
      }
    }
  }
}
