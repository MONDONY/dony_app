import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

/// Ce que la suppression du compte fera d'un solde wallet, par devise :
/// [refundableAmount] repart vers l'utilisateur par [rail] (`STRIPE`
/// automatique, `MANUAL` par ticket admin), [forfeitedAmount] est perdu à la
/// finalisation, [inFlightAmount] est déjà en cours de remboursement.
class WalletSettlement {
  final String currency;
  final double refundableAmount;
  final double forfeitedAmount;
  final double inFlightAmount;
  final String rail;

  const WalletSettlement({
    required this.currency,
    required this.refundableAmount,
    required this.forfeitedAmount,
    required this.inFlightAmount,
    required this.rail,
  });

  bool get isManual => rail == 'MANUAL';

  factory WalletSettlement.fromJson(Map<String, dynamic> json) =>
      WalletSettlement(
        currency: json['currency'] as String,
        refundableAmount: (json['refundableAmount'] as num?)?.toDouble() ?? 0,
        forfeitedAmount: (json['forfeitedAmount'] as num?)?.toDouble() ?? 0,
        inFlightAmount: (json['inFlightAmount'] as num?)?.toDouble() ?? 0,
        rail: json['rail'] as String? ?? 'STRIPE',
      );
}

class DeletionEligibility {
  final bool canDelete;
  final String? blockedReasonCode;

  /// Informatif uniquement — un solde wallet positif ne bloque plus jamais
  /// [canDelete] (Apple 5.1.1(v) : la suppression de compte doit toujours
  /// rester possible en self-service). Sert juste à prévenir l'utilisateur
  /// qu'un ticket de remboursement sera ouvert automatiquement.
  final bool hasWalletBalance;

  /// Récapitulatif de règlement du wallet par devise, exposé par le back
  /// depuis dony-back #302. `null` sur l'ancien contrat (absent de la
  /// réponse) — à ne jamais confondre avec une liste vide.
  final List<WalletSettlement>? walletSettlement;

  const DeletionEligibility({
    required this.canDelete,
    this.blockedReasonCode,
    this.hasWalletBalance = false,
    this.walletSettlement,
  });
}

class WalletRefundRequest {
  final String currency;
  final double amount;

  const WalletRefundRequest({required this.currency, required this.amount});

  factory WalletRefundRequest.fromJson(Map<String, dynamic> json) =>
      WalletRefundRequest(
        currency: json['currency'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}

class AccountDeletionRepository {
  final ApiClient _client;

  AccountDeletionRepository(this._client);

  /// Lecture seule — permet au front de savoir *avant* la tentative si la
  /// suppression est bloquée (escrow actif, solde wallet), pour griser le
  /// bouton et expliquer pourquoi au lieu de laisser échouer la requête.
  Future<DeletionEligibility> checkEligibility() async {
    try {
      final response = await _client.dio.get('/auth/me/deletion-eligibility');
      final data = response.data as Map<String, dynamic>;
      final settlementRaw = data['walletSettlement'] as List<dynamic>?;
      return DeletionEligibility(
        canDelete: data['canDelete'] as bool,
        blockedReasonCode: data['blockedReasonCode'] as String?,
        hasWalletBalance: data['hasWalletBalance'] as bool? ?? false,
        walletSettlement: settlementRaw
            ?.map((e) => WalletSettlement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  /// Remboursement Stripe automatique sur tout le remboursable, ticket
  /// manuel seulement en repli — optionnel, la suppression de compte ouvre
  /// déjà ce même remboursement automatiquement si besoin. Utile pour qui
  /// veut être remboursé sans attendre ou sans supprimer son compte.
  Future<List<WalletRefundRequest>> requestWalletRefund() async {
    try {
      final response = await _client.dio.post('/auth/me/wallet-refund-request');
      final data = response.data as List<dynamic>;
      return data
          .map((e) => WalletRefundRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<void> requestDeletion() async {
    try {
      await _client.dio.delete('/auth/me');
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<UserModel> reactivateAccount() async {
    try {
      final response = await _client.dio.post('/auth/me/reactivate');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<void> deleteImmediately() async {
    try {
      await _client.dio.post(
        '/auth/me/delete-immediately',
        data: {'confirmationAcknowledged': true},
      );
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
