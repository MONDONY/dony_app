import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_code_redemption_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class WalletTopupCodeState {
  const WalletTopupCodeState();
}

class WalletTopupCodeIdle extends WalletTopupCodeState {
  const WalletTopupCodeIdle();
}

class WalletTopupCodeSubmitting extends WalletTopupCodeState {
  const WalletTopupCodeSubmitting();
}

class WalletTopupCodeSuccess extends WalletTopupCodeState {
  const WalletTopupCodeSuccess(this.redemption);
  final WalletTopupCodeRedemptionModel redemption;
}

class WalletTopupCodeFailure extends WalletTopupCodeState {
  const WalletTopupCodeFailure(this.error);
  final AppException error;
}

/// Utilisation d'un code de recharge depuis la sheet dédiée.
class WalletTopupCodeCubit extends Cubit<WalletTopupCodeState> {
  WalletTopupCodeCubit(this._repository) : super(const WalletTopupCodeIdle());

  final WalletRepository _repository;

  Future<void> submit(String code) async {
    // Double tap : le premier appel suffit, le serveur protège de toute façon.
    if (state is WalletTopupCodeSubmitting) return;
    if (code.trim().isEmpty) return;
    emit(const WalletTopupCodeSubmitting());
    try {
      final redemption = await _repository.redeemTopupCode(code);
      if (isClosed) return;
      emit(WalletTopupCodeSuccess(redemption));
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      // Sur cette route, un code inconnu répond 422 : un 404 signifie que la
      // route n'existe pas encore (back non déployé), pas « introuvable ».
      emit(
        WalletTopupCodeFailure(
          error is NotFoundException
              ? const ServiceUnavailableException()
              : error,
        ),
      );
    }
  }

  /// Efface l'erreur affichée dès que l'utilisateur modifie le champ.
  void clearError() {
    if (state is WalletTopupCodeFailure) emit(const WalletTopupCodeIdle());
  }
}
