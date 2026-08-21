import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_eligible_topup_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletEligibleTopupsState {
  const WalletEligibleTopupsState({
    this.isLoading = true,
    this.topups = const [],
    this.error,
  });

  final bool isLoading;
  final List<WalletEligibleTopupModel> topups;
  final AppException? error;

  WalletEligibleTopupsState copyWith({
    bool? isLoading,
    List<WalletEligibleTopupModel>? topups,
    AppException? error,
  }) {
    return WalletEligibleTopupsState(
      isLoading: isLoading ?? this.isLoading,
      topups: topups ?? this.topups,
      error: error,
    );
  }
}

class WalletEligibleTopupsCubit extends Cubit<WalletEligibleTopupsState> {
  WalletEligibleTopupsCubit(this._repository)
    : super(const WalletEligibleTopupsState());

  final WalletRepository _repository;

  Future<void> load(String currency) async {
    emit(state.copyWith(isLoading: true));
    try {
      final topups = await _repository.getRefundEligibleTopups(currency);
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, topups: topups));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: unwrapDioError(e)));
      }
    }
  }
}
