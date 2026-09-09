import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';

class MobileMoneyRepository {
  const MobileMoneyRepository(this._datasource);
  final MobileMoneyRemoteDatasource _datasource;

  Future<MobileMoneyPaymentStatus> getStatus(String bidId) =>
      _datasource.getStatus(bidId);

  Future<MobileMoneyPaymentStatus> initiate(
    String bidId, {
    String? phoneNumber,
  }) => _datasource.initiate(bidId, phoneNumber: phoneNumber);
}
