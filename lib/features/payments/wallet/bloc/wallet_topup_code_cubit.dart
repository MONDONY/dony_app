import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
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
  WalletTopupCodeCubit(this._repository, {AnalyticsService? analytics})
    : _analytics = analytics,
      super(const WalletTopupCodeIdle());

  final WalletRepository _repository;
  final AnalyticsService? _analytics;

  /// Recharge par code (`method: voucher`) : aucun suivi n'existait. Doublée
  /// de `payment_succeeded` / `payment_failed` (`context: wallet_topup`).
  void _log(String topupEvent, Map<String, Object> properties) {
    final analytics = _analytics;
    if (analytics == null) return;
    final withMethod = {
      'method': AnalyticsPaymentMethod.voucher,
      ...properties,
    };
    unawaited(analytics.logEvent(topupEvent, properties: withMethod));
    unawaited(
      analytics.logEvent(
        topupEvent == AnalyticsEvents.walletTopupCompleted
            ? AnalyticsEvents.paymentSucceeded
            : AnalyticsEvents.paymentFailed,
        properties: {
          ...withMethod,
          'context': AnalyticsPaymentContext.walletTopup,
        },
      ),
    );
  }

  Future<void> submit(String code) async {
    // Double tap : le premier appel suffit, le serveur protège de toute façon.
    if (state is WalletTopupCodeSubmitting) return;
    if (code.trim().isEmpty) return;
    emit(const WalletTopupCodeSubmitting());
    try {
      final redemption = await _repository.redeemTopupCode(code);
      if (isClosed) return;
      emit(WalletTopupCodeSuccess(redemption));
      _log(AnalyticsEvents.walletTopupCompleted, {
        'currency': redemption.currency,
        'amount_bracket': analyticsAmountBracket(redemption.amount),
      });
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      // Jamais le code saisi : seulement le code d'erreur métier.
      _log(AnalyticsEvents.walletTopupFailed, {
        'reason': 'code_rejected',
        'error_code': error.code ?? 'unknown',
      });
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
