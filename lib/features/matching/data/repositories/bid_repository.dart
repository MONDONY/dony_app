import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

class BidRepository {
  final BidRemoteDatasource _datasource;

  BidRepository(this._datasource);

  Future<BidCheckoutResponseModel> checkoutBid({
    required String announcementId,
    required double weightKg,
    required double declaredValueEur,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
  }) =>
      _datasource.checkoutBid(
        announcementId: announcementId,
        weightKg: weightKg,
        declaredValueEur: declaredValueEur,
        description: description,
        contentCategory: contentCategory,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
      );

  Future<BidModel> createBid({
    required String announcementId,
    required double weightKg,
    required double declaredValueEur,
    required String description,
    required String contentCategory,
    required String recipientName,
    required String recipientPhone,
  }) =>
      _datasource.createBid(
        announcementId: announcementId,
        weightKg: weightKg,
        declaredValueEur: declaredValueEur,
        description: description,
        contentCategory: contentCategory,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
      );

  Future<List<BidModel>> getBidsForAnnouncement(String announcementId) =>
      _datasource.getBidsForAnnouncement(announcementId);

  Future<BidModel> getBidById(String bidId) =>
      _datasource.getBidById(bidId);

  Future<List<BidModel>> getMyBids() =>
      _datasource.getMyBids();

  Future<BidModel> acceptBid(String bidId) =>
      _datasource.acceptBid(bidId);

  Future<BidModel> rejectBid(String bidId, {String? reason}) =>
      _datasource.rejectBid(bidId, reason: reason);

  Future<BidModel> cancelBid(String bidId, {String? reason}) =>
      _datasource.cancelBid(bidId, reason: reason);

  Future<void> hideBid(String bidId) =>
      _datasource.hideBid(bidId);

  Future<void> dismissBidAsTraveler(String bidId) =>
      _datasource.dismissBidAsTraveler(bidId);

  Future<BidModel> setHandover({
    required String bidId,
    required String location,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) =>
      _datasource.setHandover(
        bidId: bidId,
        location: location,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

  Future<BidModel> confirmPresence(String bidId) =>
      _datasource.confirmPresence(bidId);

  Future<BidModel> confirmPayment(String bidId) =>
      _datasource.confirmPayment(bidId);

  Future<AcceptanceResponse> acceptBidWithCommission(String bidId) =>
      _datasource.acceptBidWithCommission(bidId);

  Future<ConfirmResponse> confirmCommissionAcceptance(String bidId) =>
      _datasource.confirmCommissionAcceptance(bidId);
}
