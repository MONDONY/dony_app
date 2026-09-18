import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_eligible_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';

class WalletRepository {
  final WalletRemoteDatasource _datasource;

  WalletRepository(this._datasource);

  Future<WalletModel> getBalance() async {
    try {
      return await _datasource.getBalance();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<String?> topupStripe({
    required double amount,
    String currencyCode = 'EUR',
  }) async {
    try {
      final data = await _datasource.topup(
        amount: amount,
        paymentMethod: 'STRIPE',
        currencyCode: currencyCode,
      );
      return data['clientSecret'] as String?;
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<List<WalletEligibleTopupModel>> getRefundEligibleTopups(
    String currency,
  ) async {
    try {
      final data = await _datasource.getRefundEligibleTopups(currency);
      return data
          .map(
            (e) => WalletEligibleTopupModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<WalletRefundRequestModel> requestRefund(
    String currency, [
    List<String> transactionIds = const [],
  ]) async {
    try {
      final data = await _datasource.requestRefund(currency, transactionIds);
      return WalletRefundRequestModel.fromJson(data);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<List<WalletRefundRequestModel>> getRefundRequests() async {
    try {
      final data = await _datasource.getRefundRequests();
      return data
          .map(
            (e) => WalletRefundRequestModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  /// Le backend déployé sert-il le rail mobile money pour les recharges ?
  ///
  /// La prod peut être gelée sur une version antérieure au lot 2 : proposer
  /// la tuile « Mobile money » y mènerait à un 404 puis à un « Réessayer »
  /// qui ne réussira jamais. Aucun drapeau serveur dédié n'existe, donc on
  /// sonde l'endpoint lui-même, sans corps. Toute erreur (404, réseau,
  /// `mobile-money-disabled`) rend `false` : l'app se rabat sur l'écran
  /// d'avant, carte bancaire seule, jamais d'exception remontée à l'UI.
  Future<bool> isMobileMoneyTopupAvailable() async {
    try {
      await _datasource.topupProvidersProbe();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Réseaux mobile money utilisables pour payer une recharge depuis
  /// [phoneNumber]. Même DTO côté back que le catalogue mobile money du
  /// paiement d'un colis : réutilise [MobileMoneyProviderCatalog].
  Future<MobileMoneyProviderCatalog> topupProviders(String phoneNumber) async {
    try {
      final data = await _datasource.topupProviders(phoneNumber);
      return MobileMoneyProviderCatalog.fromJson(data);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  /// Initie une recharge mobile money. Voir
  /// [WalletRemoteDatasource.topupMobileMoney] pour [provider].
  Future<WalletTopupModel> topupMobileMoney({
    required double amount,
    required String phoneNumber,
    String? provider,
  }) async {
    try {
      final data = await _datasource.topupMobileMoney(
        amount: amount,
        phoneNumber: phoneNumber,
        provider: provider,
      );
      return WalletTopupModel.fromJson(data);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  /// Statut d'une recharge mobile money, relu en boucle pendant l'attente du
  /// PIN opérateur.
  Future<WalletTopupStatusModel> topupStatus(String topupId) async {
    try {
      final data = await _datasource.topupStatus(topupId);
      return WalletTopupStatusModel.fromJson(data);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
