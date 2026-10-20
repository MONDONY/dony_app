import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';

/// Façade sur [MobileMoneyAccountRemoteDatasource] : comptes de versement
/// (un par code opérateur), avec repli sur l'ancien contrat (un seul compte)
/// quand le back n'a pas encore `/accounts`.
class MobileMoneyAccountRepository {
  MobileMoneyAccountRepository(this._datasource);
  final MobileMoneyAccountRemoteDatasource _datasource;

  /// Mémorisé après le premier 404 de `GET /accounts` : back ancien, on ne
  /// retente plus la route nouvelle.
  bool _legacy = false;

  /// Identifiant de la ligne unique reconstruite depuis l'ancien contrat.
  static const legacyAccountId = 'legacy';

  /// Comptes de versement. Sur un back sans `/accounts` (404), lit l'ancien
  /// contrat : au plus une ligne `legacy`, [MobileMoneyPayoutAccounts.legacy]
  /// vrai. Toute autre erreur est propagée telle quelle.
  Future<MobileMoneyPayoutAccounts> accounts() async {
    if (!_legacy) {
      try {
        return await _datasource.accounts();
      } catch (e) {
        if (unwrapDioError(e) is! NotFoundException) rethrow;
        _legacy = true;
      }
    }
    final account = await _datasource.get();
    return MobileMoneyPayoutAccounts(
      accounts: account.isActive ? [_legacyRow(account)] : const [],
      legacy: true,
    );
  }

  MobileMoneyPayoutAccount _legacyRow(MobileMoneyAccount account) {
    final provider = account.provider ?? '';
    return MobileMoneyPayoutAccount(
      id: legacyAccountId,
      provider: provider,
      providerLabel: account.providerLabel ?? provider,
      brand: MobileMoneyPayoutAccount.brandOf(provider),
      country: account.country ?? '',
      currency: account.currency ?? '',
      msisdnMasked: account.msisdnMasked ?? '',
    );
  }

  Future<void> addAccount({
    required String phoneNumber,
    required String provider,
  }) async {
    if (_legacy) {
      await _datasource.activate(
        phoneNumber: phoneNumber,
        providers: [provider],
      );
      return;
    }
    await _datasource.addAccount(phoneNumber: phoneNumber, provider: provider);
  }

  Future<void> changeNumber({
    required MobileMoneyPayoutAccount account,
    required String phoneNumber,
  }) async {
    if (_legacy) {
      await _datasource.activate(
        phoneNumber: phoneNumber,
        providers: [account.provider],
      );
      return;
    }
    await _datasource.changeNumber(id: account.id, phoneNumber: phoneNumber);
  }

  Future<void> removeAccount(MobileMoneyPayoutAccount account) async {
    if (_legacy) {
      await _datasource.disable();
      return;
    }
    await _datasource.removeAccount(account.id);
  }

  /// Pays et réseaux de versement. `null` sur 404 : back ancien sans la
  /// route, l'appelant se rabat sur l'écran d'avant.
  Future<MobileMoneyCountries?> payoutCountries() async {
    try {
      return await _datasource.payoutCountries();
    } catch (e) {
      if (unwrapDioError(e) is NotFoundException) return null;
      rethrow;
    }
  }

  /// Réseaux utilisables sur [e164] pour un nouveau compte.
  Future<MobileMoneyProviderCatalog> payoutProviders(String e164) =>
      _datasource.providers(phoneNumber: e164);
}
