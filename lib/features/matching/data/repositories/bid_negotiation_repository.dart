import 'package:dony/features/matching/data/datasources/bid_negotiation_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';

/// Pass-through vers [BidNegotiationRemoteDatasource].
///
/// Aucun try/catch ici : les erreurs remontent telles quelles jusqu'au BLoC,
/// seul endroit où elles sont traduites (`unwrapDioError`).
class BidNegotiationRepository {
  final BidNegotiationRemoteDatasource _datasource;

  BidNegotiationRepository(this._datasource);

  Future<BidNegotiation> propose({
    required String announcementId,
    required double? weightKg,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
    required double proposedTotalEur,
    BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
    String? phoneNumber,
    String? countryCode,
    List<String>? photoKeys,
    List<Map<String, dynamic>>? customItems,
    List<Map<String, dynamic>>? gridItems,
  }) => _datasource.propose(
    announcementId: announcementId,
    weightKg: weightKg,
    description: description,
    contentCategory: contentCategory,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    proposedTotalEur: proposedTotalEur,
    paymentMethod: paymentMethod,
    phoneNumber: phoneNumber,
    countryCode: countryCode,
    photoKeys: photoKeys,
    customItems: customItems,
    gridItems: gridItems,
  );

  Future<BidNegotiation> counter(
    String bidId, {
    required double proposedTotalEur,
    String? body,
  }) => _datasource.counter(
    bidId,
    proposedTotalEur: proposedTotalEur,
    body: body,
  );

  Future<BidNegotiation> accept(String bidId) => _datasource.accept(bidId);

  Future<BidNegotiation> reject(String bidId) => _datasource.reject(bidId);

  Future<BidNegotiation> cancel(String bidId) => _datasource.cancel(bidId);

  Future<BidNegotiation> thread(String bidId) => _datasource.thread(bidId);

  Future<void> markRead(String bidId) => _datasource.markRead(bidId);

  Future<List<BidNegotiationSummary>> myNegotiations() =>
      _datasource.myNegotiations();
}
