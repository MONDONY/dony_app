import 'package:dony/features/incident_report/data/report_reasons.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellés traduits d'un motif de signalement.
///
/// [ReportReason.apiValue] reste la valeur envoyée au serveur (miroir de
/// l'enum back `ReportReason`) : elle ne change jamais. Cette extension ne
/// sert que l'affichage.
extension ReportReasonL10n on ReportReason {
  String label(AppLocalizations l) => switch (this) {
    ReportReason.harassment => l.reportReasonHarassment,
    ReportReason.fakeProfile => l.reportReasonFakeProfile,
    ReportReason.scamAttempt => l.reportReasonScamAttempt,
    ReportReason.prohibitedItem => l.reportReasonProhibitedItem,
    ReportReason.falseInformation => l.reportReasonFalseInformation,
    ReportReason.inappropriateContent => l.reportReasonInappropriateContent,
    ReportReason.spam => l.reportReasonSpam,
    ReportReason.paymentIssue => l.reportReasonPaymentIssue,
    ReportReason.appBug => l.reportReasonAppBug,
    ReportReason.other => l.reportReasonOther,
  };
}
