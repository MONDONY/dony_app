import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';

class CancellationRepository {
  final CancellationRemoteDatasource _datasource;

  CancellationRepository(this._datasource);

  Future<CancellationModel> cancelTrip({
    required String announcementId,
    required String reason,
  }) => _datasource.cancelTrip(announcementId: announcementId, reason: reason);

  Future<List<RematchSuggestionModel>> getRematchSuggestions(
    String cancellationId,
  ) => _datasource.getRematchSuggestions(cancellationId);

  Future<void> reportNoShow(String bidId) => _datasource.reportNoShow(bidId);

  Future<void> reportTravelerNoShow(String bidId) =>
      _datasource.reportTravelerNoShow(bidId);

  Future<void> contestNoShow(String bidId) => _datasource.contestNoShow(bidId);

  Future<void> decideReschedule(String bidId, {required bool keep}) =>
      _datasource.decideReschedule(bidId, keep: keep);

  Future<void> reportDeliveryNoShow(
    String bidId, {
    bool contactConfirmed = false,
  }) => _datasource.reportDeliveryNoShow(
    bidId,
    contactConfirmed: contactConfirmed,
  );

  Future<DeliveryNoShowProcedureModel> getDeliveryNoShowProcedure(
    String bidId,
  ) => _datasource.getDeliveryNoShowProcedure(bidId);

  Future<DeliveryNoShowProcedureModel> setRetryAppointment(
    String bidId, {
    required DateTime appointmentAt,
    String? note,
  }) => _datasource.setRetryAppointment(
    bidId,
    appointmentAt: appointmentAt,
    note: note,
  );

  Future<void> reportTravelerDeliveryNoShow(String bidId) =>
      _datasource.reportTravelerDeliveryNoShow(bidId);

  Future<void> contestDeliveryNoShow(String bidId) =>
      _datasource.contestDeliveryNoShow(bidId);

  Future<void> confirmNoShow(String bidId) => _datasource.confirmNoShow(bidId);

  Future<void> cancelAfterHandover(String bidId) =>
      _datasource.cancelAfterHandover(bidId);

  Future<ReturnCodeModel> confirmReturn(String bidId, String code) =>
      _datasource.confirmReturn(bidId, code);

  Future<ReturnCodeModel> getReturnCode(String bidId) =>
      _datasource.getReturnCode(bidId);
}
