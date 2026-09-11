import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';

class MobileMoneyRepository {
  const MobileMoneyRepository(this._datasource);
  final MobileMoneyRemoteDatasource _datasource;

  Future<MobileMoneyPaymentStatus> getStatus(MobileMoneyScope scope) =>
      _datasource.getStatus(scope);

  Future<MobileMoneyPaymentStatus> initiate(
    MobileMoneyScope scope, {
    String? phoneNumber,
  }) => _datasource.initiate(scope, phoneNumber: phoneNumber);
}
