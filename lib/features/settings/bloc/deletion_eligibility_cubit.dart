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
/// de la tentative réelle. Le message à afficher n'est pas stocké ici : la
/// présentation (`deletionBlockedMessage`, `deletion_labels.dart`) le calcule
/// à la demande à partir de [blockedReasonCode], pour suivre un changement de
/// langue sans repasser par le serveur.
class DeletionEligibilityState {
  const DeletionEligibilityState({
    this.isLoading = true,
    this.canDelete = true,
    this.blockedReasonCode,
    this.hasWalletBalance = false,
    this.walletRefundRequests = const [],
    this.isRequestingWalletRefund = false,
    this.walletRefundError,
    this.walletSettlement,
  });

  final bool isLoading;
  final bool canDelete;
  final String? blockedReasonCode;

  /// Informatif uniquement — un solde wallet positif n'a plus jamais bloqué
  /// [canDelete] côté backend depuis Apple 5.1.1(v). Sert seulement à
  /// prévenir l'utilisateur qu'un ticket de remboursement sera ouvert
  /// automatiquement à la suppression.
  final bool hasWalletBalance;

  /// Non vide dès que le ticket de remboursement a été ouvert côté serveur
  /// (une entrée par devise en solde positif) — sert de source de vérité pour
  /// basculer le CTA vers son état "demande envoyée", pas juste un booléen :
  /// affiche aussi le montant exact du ticket ouvert.
  final List<WalletRefundRequest> walletRefundRequests;
  final bool isRequestingWalletRefund;
  final AppException? walletRefundError;

  /// Récapitulatif de règlement du wallet par devise, `null` sur l'ancien
  /// contrat back (sheet de suppression : tâche 5).
  final List<WalletSettlement>? walletSettlement;

  bool get walletRefundRequested => walletRefundRequests.isNotEmpty;

  DeletionEligibilityState copyWith({
    bool? isLoading,
    bool? canDelete,
    String? blockedReasonCode,
    bool? hasWalletBalance,
    List<WalletRefundRequest>? walletRefundRequests,
    bool? isRequestingWalletRefund,
    AppException? walletRefundError,
    bool clearWalletRefundError = false,
    List<WalletSettlement>? walletSettlement,
  }) {
    return DeletionEligibilityState(
      isLoading: isLoading ?? this.isLoading,
      canDelete: canDelete ?? this.canDelete,
      blockedReasonCode: blockedReasonCode ?? this.blockedReasonCode,
      hasWalletBalance: hasWalletBalance ?? this.hasWalletBalance,
      walletRefundRequests: walletRefundRequests ?? this.walletRefundRequests,
      isRequestingWalletRefund:
          isRequestingWalletRefund ?? this.isRequestingWalletRefund,
      walletRefundError: clearWalletRefundError
          ? null
          : (walletRefundError ?? this.walletRefundError),
      walletSettlement: walletSettlement ?? this.walletSettlement,
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
            canDelete: eligibility.canDelete,
            blockedReasonCode: eligibility.blockedReasonCode,
            hasWalletBalance: eligibility.hasWalletBalance,
            walletSettlement: eligibility.walletSettlement,
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

  /// Demande le remboursement du montant remboursable du portefeuille :
  /// automatique par Stripe sur les recharges d'origine quand elles le
  /// permettent, ticket manuel traité par un admin seulement en repli. Le
  /// bonus non remboursable reste sur le solde. Ne conditionne jamais la
  /// suppression du compte.
  Future<void> requestWalletRefund() async {
    emit(
      state.copyWith(
        isRequestingWalletRefund: true,
        clearWalletRefundError: true,
      ),
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
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletRefundRequested,
          properties: const {'source': 'account_deletion'},
        ),
      );
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
}
