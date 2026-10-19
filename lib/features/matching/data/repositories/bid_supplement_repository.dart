import 'package:dony/features/matching/data/datasources/bid_supplement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';

/// Supplément de prix à la remise, côté voyageur et côté expéditeur.
class BidSupplementRepository {
  const BidSupplementRepository(this._datasource);

  final BidSupplementRemoteDatasource _datasource;

  Future<SupplementOptions> options(String bidId) => _datasource.options(bidId);

  Future<SupplementQuote> quote(String bidId, double netAmount) =>
      _datasource.quote(bidId, netAmount);

  Future<String> uploadPhoto(String bidId, String filePath) =>
      _datasource.uploadPhoto(bidId, filePath);

  Future<BidSupplement> create(
    String bidId, {
    required double netAmount,
    required BidSupplementReason reason,
    String? reasonText,
    String? gridItemLabel,
    required String photoKey,
  }) => _datasource.create(
    bidId,
    netAmount: netAmount,
    reason: reason,
    reasonText: reasonText,
    gridItemLabel: gridItemLabel,
    photoKey: photoKey,
  );

  Future<BidSupplement> withdraw(String bidId, String supplementId) =>
      _datasource.withdraw(bidId, supplementId);

  Future<BidSupplement> decline(String bidId, String supplementId) =>
      _datasource.decline(bidId, supplementId);
}
