import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';

/// Façade 1:1 sur [MobileMoneyAccountRemoteDatasource].
class MobileMoneyAccountRepository {
  const MobileMoneyAccountRepository(this._datasource);
  final MobileMoneyAccountRemoteDatasource _datasource;

  Future<MobileMoneyAccount> get() => _datasource.get();

  /// Voir [MobileMoneyAccountRemoteDatasource.activate] pour [phoneNumber].
  /// Le repli sans argument (plutôt que `phoneNumber: null`) évite d'envoyer
  /// un named argument explicite au datasource quand il n'y a rien à
  /// transmettre.
  Future<MobileMoneyAccount> activate({String? phoneNumber}) =>
      phoneNumber != null
      ? _datasource.activate(phoneNumber: phoneNumber)
      : _datasource.activate();

  Future<MobileMoneyAccount> disable() => _datasource.disable();
}
