import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
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
      // Tracé après succès, comme depuis la suppression de compte. Devise,
      // moyen de retour et tranche (jamais le montant exact) : sans eux, les
      // remboursements ne se lisaient par aucun type.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletRefundRequested,
          properties: walletRefundAnalyticsProperties(
            result,
            source: 'wallet',
            transactionCount: transactionIds.length,
          ),
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletRefundFailed,
          properties: {
            'source': 'wallet',
            'currency': currency,
            'error_code': error.code ?? 'unknown',
          },
        ),
      );
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false, error: error));
      }
    }
  }
}

/// Propriétés d'une demande de remboursement acceptée, sans PII : `source`,
/// `currency`, `method` (moyen de retour, voir [analyticsRefundMethod]),
/// `amount_bracket`, `status`, et `transaction_count` quand il est connu.
Map<String, Object> walletRefundAnalyticsProperties(
  WalletRefundRequestModel request, {
  required String source,
  int? transactionCount,
}) => {
  'source': source,
  'currency': request.currency,
  'method': analyticsRefundMethod(request.rail),
  'amount_bracket': analyticsAmountBracket(request.amount),
  'status': request.status,
  'transaction_count': ?transactionCount,
};
