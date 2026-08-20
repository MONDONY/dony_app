import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

class DeletionEligibility {
  final bool canDelete;
  final String? blockedReasonCode;

  /// Informatif uniquement — un solde wallet positif ne bloque plus jamais
  /// [canDelete] (Apple 5.1.1(v) : la suppression de compte doit toujours
  /// rester possible en self-service). Sert juste à prévenir l'utilisateur
  /// qu'un ticket de remboursement sera ouvert automatiquement.
  final bool hasWalletBalance;

  const DeletionEligibility({
    required this.canDelete,
    this.blockedReasonCode,
    this.hasWalletBalance = false,
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
      return DeletionEligibility(
        canDelete: data['canDelete'] as bool,
        blockedReasonCode: data['blockedReasonCode'] as String?,
        hasWalletBalance: data['hasWalletBalance'] as bool? ?? false,
      );
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  /// Ouvre un ticket de remboursement manuel pour chaque devise en solde
  /// wallet positif (aucun remboursement automatique n'existe côté Stripe
  /// pour le wallet) — optionnel, la suppression de compte ouvre déjà ce
  /// même ticket automatiquement si besoin. Utile pour qui veut être
  /// remboursé sans attendre ou sans supprimer son compte.
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
