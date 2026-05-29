import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletRepository _repository;

  WalletBloc(this._repository) : super(WalletInitial()) {
    on<WalletLoadRequested>(_onLoad);
    on<WalletTopupRequested>(_onTopup);
  }

  Future<void> _onLoad(
    WalletLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final wallet = await _repository.getBalance();
      emit(WalletLoaded(wallet));
    } catch (e) {
      emit(WalletError(unwrapDioError(e).message));
    }
  }

  Future<void> _onTopup(
    WalletTopupRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      switch (event.paymentMethod) {
        case 'STRIPE':
          final clientSecret =
              await _repository.topupStripe(amount: event.amount);
          emit(clientSecret != null
              ? WalletTopupStripeReady(clientSecret)
              : WalletError('Réponse vide du serveur'));
        case 'WAVE':
          final url = await _repository.topupWave(amount: event.amount);
          emit(url != null
              ? WalletTopupRedirectReady(url)
              : WalletError('Réponse vide du serveur'));
        case 'ORANGE_MONEY':
          final url2 =
              await _repository.topupOrangeMoney(amount: event.amount);
          emit(url2 != null
              ? WalletTopupRedirectReady(url2)
              : WalletError('Réponse vide du serveur'));
      }
    } catch (e) {
      emit(WalletError(unwrapDioError(e).message));
    }
  }
}
