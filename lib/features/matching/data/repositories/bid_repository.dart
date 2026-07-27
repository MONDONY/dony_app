import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:dony/features/matching/data/models/traveler_bids_page.dart';

class BidRepository {
  final BidRemoteDatasource _datasource;

  BidRepository(this._datasource);

  Future<String> uploadBidPhoto(String filePath) =>
      _datasource.uploadBidPhoto(filePath);

  Future<BidCheckoutResponseModel> checkoutBid({
    required String announcementId,
    required double weightKg,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
    List<String>? photoKeys,
    List<Map<String, dynamic>>? gridItems,
  }) => _datasource.checkoutBid(
    announcementId: announcementId,
    weightKg: weightKg,
    description: description,
    contentCategory: contentCategory,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    photoKeys: photoKeys,
    gridItems: gridItems,
  );

  Future<BidQuoteResponse> quoteBid({
    required String announcementId,
    double? weightKg,
    String? promoCode,
    List<Map<String, dynamic>>? gridItems,
  }) => _datasource.quoteBid(
    announcementId: announcementId,
    weightKg: weightKg,
    promoCode: promoCode,
    gridItems: gridItems,
  );

  Future<BidModel> createBid({
    required String announcementId,
    required double weightKg,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
    BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
    String? phoneNumber,
    String? countryCode,
    String? promoCode,
    List<String>? photoKeys,
    List<Map<String, dynamic>>? gridItems,
  }) => _datasource.createBid(
    announcementId: announcementId,
    weightKg: weightKg,
    description: description,
    contentCategory: contentCategory,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    paymentMethod: paymentMethod,
    phoneNumber: phoneNumber,
    countryCode: countryCode,
    promoCode: promoCode,
    photoKeys: photoKeys,
    gridItems: gridItems,
  );

  Future<List<BidModel>> getBidsForAnnouncement(String announcementId) =>
      _datasource.getBidsForAnnouncement(announcementId);

  Future<BidModel> getBidById(String bidId) => _datasource.getBidById(bidId);

  Future<List<BidModel>> getMyBids() => _datasource.getMyBids();

  /// Numéro de la contrepartie, récupéré au moment de l'appel téléphonique.
  Future<String?> getCounterpartyPhone(String bidId) =>
      _datasource.getCounterpartyPhone(bidId);

  Future<TravelerBidsPage> getTravelerBids({int page = 0, int size = 20}) =>
      _datasource.getTravelerBids(page: page, size: size);

  Future<BidModel> acceptBid(String bidId) => _datasource.acceptBid(bidId);

  Future<BidModel> rejectBid(String bidId, {String? reason}) =>
      _datasource.rejectBid(bidId, reason: reason);

  Future<BidModel> cancelBid(String bidId, {String? reason}) =>
      _datasource.cancelBid(bidId, reason: reason);

  Future<void> hideBid(String bidId) => _datasource.hideBid(bidId);

  Future<void> dismissBidAsTraveler(String bidId) =>
      _datasource.dismissBidAsTraveler(bidId);

  Future<BidModel> confirmPresence(String bidId) =>
      _datasource.confirmPresence(bidId);

  Future<BidModel> confirmPayment(String bidId) =>
      _datasource.confirmPayment(bidId);

  Future<AcceptanceResponse> acceptBidWithCommission(
    String bidId, {
    String commissionSource = 'WALLET_FIRST',
  }) => _datasource.acceptBidWithCommission(
    bidId,
    commissionSource: commissionSource,
  );

  Future<ConfirmResponse> confirmCommissionAcceptance(String bidId) =>
      _datasource.confirmCommissionAcceptance(bidId);
}
