import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';

/// Façade 1:1 sur [MobileMoneyAccountRemoteDatasource].
class MobileMoneyAccountRepository {
  const MobileMoneyAccountRepository(this._datasource);
  final MobileMoneyAccountRemoteDatasource _datasource;

  Future<MobileMoneyAccount> get() => _datasource.get();

  Future<MobileMoneyAccount> activate() => _datasource.activate();

  Future<MobileMoneyAccount> disable() => _datasource.disable();
}
