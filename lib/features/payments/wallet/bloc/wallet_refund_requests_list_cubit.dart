import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletRefundRequestsListState {
  const WalletRefundRequestsListState({
    this.isLoading = true,
    this.requests = const [],
    this.error,
  });

  final bool isLoading;
  final List<WalletRefundRequestModel> requests;
  final AppException? error;

  WalletRefundRequestsListState copyWith({
    bool? isLoading,
    List<WalletRefundRequestModel>? requests,
    AppException? error,
  }) {
    return WalletRefundRequestsListState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      error: error,
    );
  }
}

class WalletRefundRequestsListCubit
    extends Cubit<WalletRefundRequestsListState> {
  WalletRefundRequestsListCubit(this._repository)
    : super(const WalletRefundRequestsListState());

  final WalletRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final requests = await _repository.getRefundRequests();
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, requests: requests));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: unwrapDioError(e)));
      }
    }
  }
}
