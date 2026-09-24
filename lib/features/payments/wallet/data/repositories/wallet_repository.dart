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
    String currencyCode =
        'EUR', // i18n-ignore : code devise par défaut envoyé au serveur
  }) async {
    try {
      final data = await _datasource.topup(
        amount: amount,
        paymentMethod:
            'STRIPE', // i18n-ignore : code de méthode de paiement envoyé au serveur
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

  /// Codes métier qui prouvent que la route de catalogue EXISTE et que le
  /// rail mobile money est servi : le back a bien exécuté sa validation du
  /// numéro payeur, il n'a donc pas pu répondre un 404 de route absente ni
  /// un rail désactivé.
  static const _mobileMoneyServedCodes = {
    'topup-phone-required',
    'mobile-money-invalid-phone',
  };

  /// Le backend déployé sert-il le rail mobile money pour les recharges ?
  ///
  /// La prod peut être gelée sur une version antérieure au lot 2 : proposer
  /// la tuile « Mobile money » y mènerait à un 404 puis à un « Réessayer »
  /// qui ne réussira jamais. Aucun drapeau serveur dédié n'existe, donc on
  /// sonde l'endpoint lui-même, sans corps.
  ///
  /// La sonde ABOUTIT NORMALEMENT EN ERREUR : sans numéro, le back valide et
  /// répond 422 `topup-phone-required` (figé côté back par un test
  /// d'intégration). Juger sur « ça a levé » masquerait donc la tuile même
  /// sur un backend qui sert le rail — la décision se prend sur le CODE
  /// métier de l'erreur ([AppException.code], renseigné depuis le `code` du
  /// ProblemDetail par l'intercepteur) :
  /// - `topup-phone-required` / `mobile-money-invalid-phone` → servi ;
  /// - `mobile-money-disabled`, 404, 403, réseau, tout le reste → non servi.
  ///
  /// Jamais d'exception remontée à l'UI : l'app se rabat sur l'écran
  /// d'avant, carte bancaire seule.
  Future<bool> isMobileMoneyTopupAvailable() async {
    try {
      await _datasource.topupProvidersProbe();
      // Un back qui accepte la sonde sans corps sert forcément le rail.
      return true;
    } catch (e) {
      return _mobileMoneyServedCodes.contains(unwrapDioError(e).code);
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
