import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_model.dart';

class MobileMoneyRepository {
  const MobileMoneyRepository(this._datasource);
  final MobileMoneyRemoteDatasource _datasource;

  Future<MobileMoneyPaymentModel> getStatus(String bidId) =>
      _datasource.getStatus(bidId);

  Future<MobileMoneyPaymentModel> regenerateLink(String bidId) =>
      _datasource.regenerateLink(bidId);
}
