import 'package:dony/features/matching/data/datasources/bid_amendment_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';

/// Modification d'un colis accepté, côté expéditeur et côté voyageur.
class BidAmendmentRepository {
  const BidAmendmentRepository(this._datasource);

  final BidAmendmentRemoteDatasource _datasource;

  Future<AmendmentOptions> options(String bidId) => _datasource.options(bidId);

  Future<double> quote(
    String bidId, {
    required double addedKg,
    required Map<String, int> items,
  }) => _datasource.quote(bidId, addedKg: addedKg, items: items);

  Future<AmendmentCheckout> create(
    String bidId, {
    required double addedKg,
    required Map<String, int> items,
    required BidPaymentMethod method,
  }) =>
      _datasource.create(bidId, addedKg: addedKg, items: items, method: method);

  Future<BidAmendment> confirmAuthorization(String bidId, String id) =>
      _datasource.confirmAuthorization(bidId, id);

  Future<BidAmendment> cancel(String bidId, String id) =>
      _datasource.cancel(bidId, id);

  Future<BidAmendment> decline(String bidId, String id) =>
      _datasource.decline(bidId, id);

  Future<BidAmendment> notBrought(String bidId, String id) =>
      _datasource.notBrought(bidId, id);

  Future<BidAmendment> confirmCommission(String bidId, String id) =>
      _datasource.confirmCommission(bidId, id);

  Future<BidAmendment> accept(
    String bidId,
    String id, {
    SupplementCommissionSource? commissionSource,
    String? fundingCurrency,
  }) => _datasource.accept(
    bidId,
    id,
    commissionSource: commissionSource,
    fundingCurrency: fundingCurrency,
  );
}
