import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';

/// Façade 1:1 sur [MobileMoneyAccountRemoteDatasource].
class MobileMoneyAccountRepository {
  const MobileMoneyAccountRepository(this._datasource);
  final MobileMoneyAccountRemoteDatasource _datasource;

  Future<MobileMoneyAccount> get() => _datasource.get();

  /// Voir [MobileMoneyAccountRemoteDatasource.providers] pour [phoneNumber].
  /// Le repli sans argument (plutôt que `phoneNumber: null`) évite d'envoyer
  /// un named argument explicite au datasource quand il n'y a rien à
  /// transmettre.
  Future<MobileMoneyProviderCatalog> providers({String? phoneNumber}) =>
      phoneNumber != null
      ? _datasource.providers(phoneNumber: phoneNumber)
      : _datasource.providers();

  /// Voir [MobileMoneyAccountRemoteDatasource.activate]. [providers] est
  /// toujours transmis (vide par défaut) : le datasource décide seul de ce
  /// qui rentre dans le corps de la requête.
  Future<MobileMoneyAccount> activate({
    String? phoneNumber,
    List<String> providers = const [],
  }) => _datasource.activate(phoneNumber: phoneNumber, providers: providers);

  /// Voir [MobileMoneyAccountRemoteDatasource.updateProviders].
  Future<MobileMoneyAccount> updateProviders(List<String> providers) =>
      _datasource.updateProviders(providers);

  Future<MobileMoneyAccount> disable() => _datasource.disable();
}
