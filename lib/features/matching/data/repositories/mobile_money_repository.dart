import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';

class MobileMoneyRepository {
  const MobileMoneyRepository(this._datasource);
  final MobileMoneyRemoteDatasource _datasource;

  Future<MobileMoneyPaymentStatus> getStatus(MobileMoneyScope scope) =>
      _datasource.getStatus(scope);

  Future<MobileMoneyProviderCatalog> providers(
    String bidId, {
    String? phoneNumber,
  }) => _datasource.providers(bidId, phoneNumber: phoneNumber);

  Future<MobileMoneyPaymentStatus> initiate(
    MobileMoneyScope scope, {
    String? phoneNumber,
  }) => _datasource.initiate(scope, phoneNumber: phoneNumber);
}
