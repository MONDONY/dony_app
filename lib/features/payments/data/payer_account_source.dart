import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';

/// Catalogue servi au composant « compte qui paie » : pays et opérateurs
/// ouverts, et reconnaissance d'un numéro par pawaPay.
///
/// La recharge lit le catalogue des dépôts, l'ajout d'un compte de versement
/// celui des versements : un opérateur peut être ouvert à l'un et pas à
/// l'autre.
abstract interface class PayerAccountSource {
  /// Pays servis et « Bientôt ». `null` : back ancien sans le catalogue,
  /// l'appelant se rabat sur l'écran d'avant.
  Future<MobileMoneyCountries?> countries();

  /// Opérateur prédit pour [e164]. Les erreurs sortent en [AppException],
  /// pour que le code (`mobile-money-invalid-phone`...) soit lisible.
  Future<MobileMoneyProviderCatalog> recognize(String e164);
}

/// Catalogue des dépôts (recharge du solde, paiement).
class TopupPayerAccountSource implements PayerAccountSource {
  const TopupPayerAccountSource(this._repository);

  final WalletRepository _repository;

  @override
  Future<MobileMoneyCountries?> countries() =>
      _repository.mobileMoneyCountries();

  @override
  Future<MobileMoneyProviderCatalog> recognize(String e164) =>
      _repository.topupProviders(e164);
}

/// Catalogue des versements (ajout d'un compte mobile money qui reçoit).
class PayoutPayerAccountSource implements PayerAccountSource {
  const PayoutPayerAccountSource(this._repository);

  final MobileMoneyAccountRepository _repository;

  @override
  Future<MobileMoneyCountries?> countries() => _repository.payoutCountries();

  @override
  Future<MobileMoneyProviderCatalog> recognize(String e164) async {
    try {
      return await _repository.payoutProviders(e164);
    } catch (e) {
      // Le dépôt des comptes laisse passer la DioException : sans la
      // déballer, un numéro invalide passerait pour une coupure réseau.
      throw unwrapDioError(e);
    }
  }
}
