import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';

class CancellationRepository {
  final CancellationRemoteDatasource _datasource;

  CancellationRepository(this._datasource);

  Future<CancellationModel> cancelTrip({
    required String announcementId,
    required String reason,
  }) =>
      _datasource.cancelTrip(announcementId: announcementId, reason: reason);

  Future<List<RematchSuggestionModel>> getRematchSuggestions(String cancellationId) =>
      _datasource.getRematchSuggestions(cancellationId);

  Future<void> reportNoShow(String bidId) =>
      _datasource.reportNoShow(bidId);

  Future<void> reportTravelerNoShow(String bidId) =>
      _datasource.reportTravelerNoShow(bidId);

  Future<void> contestNoShow(String bidId) =>
      _datasource.contestNoShow(bidId);
}
