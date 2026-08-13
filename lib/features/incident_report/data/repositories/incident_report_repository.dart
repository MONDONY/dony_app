import 'package:dony/features/incident_report/data/datasources/incident_report_remote_datasource.dart';

/// Cible d'un signalement — miroir de l'enum backend ReportTargetType.
enum IncidentTargetType { user, announcement, bid, message, rating, app }

extension IncidentTargetTypeApi on IncidentTargetType {
  String get apiValue => switch (this) {
    IncidentTargetType.user => 'USER',
    IncidentTargetType.announcement => 'ANNOUNCEMENT',
    IncidentTargetType.bid => 'BID',
    IncidentTargetType.message => 'MESSAGE',
    IncidentTargetType.rating => 'RATING',
    IncidentTargetType.app => 'APP',
  };
}

class IncidentReportRepository {
  final IncidentReportRemoteDatasource _datasource;

  IncidentReportRepository(this._datasource);

  Future<String> uploadPhoto(String filePath) =>
      _datasource.uploadPhoto(filePath);

  Future<String> submit({
    required IncidentTargetType targetType,
    String? targetId,
    required String reason,
    String? description,
    List<String> photoKeys = const [],
  }) => _datasource.createReport(
    targetType: targetType.apiValue,
    targetId: targetId,
    reason: reason,
    description: description,
    photoKeys: photoKeys,
  );
}
