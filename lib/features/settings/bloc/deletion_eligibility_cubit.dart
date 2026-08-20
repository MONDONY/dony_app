import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// État de l'éligibilité à la suppression de compte, vérifiée en amont pour
/// griser le bouton de confirmation et expliquer pourquoi au lieu de laisser
/// l'utilisateur tenter une suppression qui échouera côté serveur.
///
/// [canDelete] vaut `true` tant que le check n'est pas encore résolu (ou a
/// échoué) : on ne bloque jamais préventivement sur une simple erreur réseau,
/// le backend reste de toute façon la source de vérité autoritaire au moment
/// de la tentative réelle. Il se dérive donc de [blockedReasonMessage] — un
/// blocage sans motif affichable n'est pas représentable.
class DeletionEligibilityState {
  const DeletionEligibilityState({
    this.isLoading = true,
    this.blockedReasonCode,
    this.blockedReasonMessage,
    this.walletRefundRequests = const [],
    this.isRequestingWalletRefund = false,
    this.walletRefundError,
  });

  final bool isLoading;
  final String? blockedReasonCode;
  final String? blockedReasonMessage;

  /// Non vide dès que le ticket de remboursement a été ouvert côté serveur
  /// (une entrée par devise en solde positif) — sert de source de vérité pour
  /// basculer le CTA vers son état "demande envoyée", pas juste un booléen :
  /// affiche aussi le montant exact du ticket ouvert.
  final List<WalletRefundRequest> walletRefundRequests;
  final bool isRequestingWalletRefund;
  final AppException? walletRefundError;

  bool get canDelete => blockedReasonMessage == null;

  /// Seul ce motif de blocage a un parcours de déblocage self-service — les
  /// autres (ex. `active-transactions`) n'ont qu'à attendre.
  bool get isWalletBalanceBlocked =>
      blockedReasonCode == 'wallet-balance-not-empty';

  bool get walletRefundRequested => walletRefundRequests.isNotEmpty;

  DeletionEligibilityState copyWith({
    bool? isLoading,
    String? blockedReasonCode,
    String? blockedReasonMessage,
    List<WalletRefundRequest>? walletRefundRequests,
    bool? isRequestingWalletRefund,
    AppException? walletRefundError,
    bool clearWalletRefundError = false,
  }) {
    return DeletionEligibilityState(
      isLoading: isLoading ?? this.isLoading,
      blockedReasonCode: blockedReasonCode ?? this.blockedReasonCode,
      blockedReasonMessage: blockedReasonMessage ?? this.blockedReasonMessage,
      walletRefundRequests: walletRefundRequests ?? this.walletRefundRequests,
      isRequestingWalletRefund:
          isRequestingWalletRefund ?? this.isRequestingWalletRefund,
      walletRefundError: clearWalletRefundError
          ? null
          : (walletRefundError ?? this.walletRefundError),
    );
  }
}

class DeletionEligibilityCubit extends Cubit<DeletionEligibilityState> {
  DeletionEligibilityCubit(this._repository, this._analytics)
    : super(const DeletionEligibilityState());

  final AccountDeletionRepository _repository;
  final AnalyticsService _analytics;

  Future<void> check() async {
    try {
      final eligibility = await _repository.checkEligibility();
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            blockedReasonCode: eligibility.blockedReasonCode,
            blockedReasonMessage: eligibility.canDelete
                ? null
                : _messageFor(eligibility.blockedReasonCode),
          ),
        );
      }
    } catch (_) {
      // Fail-open : le bouton reste actif, l'erreur réelle (le cas échéant)
      // sera de toute façon surfacée par AccountDeletionBloc à la tentative.
      if (!isClosed) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  /// Ouvre le ticket de remboursement manuel — ne débloque jamais la
  /// suppression elle-même, seul un admin peut le faire en résolvant le
  /// ticket après avoir remboursé via Stripe hors-app.
  Future<void> requestWalletRefund() async {
    emit(
      state.copyWith(isRequestingWalletRefund: true, clearWalletRefundError: true),
    );
    try {
      final requests = await _repository.requestWalletRefund();
      if (!isClosed) {
        emit(
          state.copyWith(
            isRequestingWalletRefund: false,
            walletRefundRequests: requests,
          ),
        );
      }
      unawaited(_analytics.logEvent(AnalyticsEvents.walletRefundRequested));
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isRequestingWalletRefund: false,
            walletRefundError: unwrapDioError(e),
          ),
        );
      }
    }
  }

  String _messageFor(String? code) {
    switch (code) {
      case 'active-transactions':
        return 'Vous avez un envoi en cours de livraison, avec des fonds '
            'bloqués en séquestre. Vous pourrez supprimer votre compte dès '
            'que la livraison sera confirmée.';
      case 'wallet-balance-not-empty':
        return 'Vous avez un solde disponible sur votre wallet. '
            'Demandez son remboursement avant de supprimer votre compte.';
      default:
        return 'La suppression n\'est pas possible pour l\'instant.';
    }
  }
}
