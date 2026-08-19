import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';

/// Motifs catalogués d'un signalement — miroir de `ReportReason` côté back
/// (com.yadony.api.signalements.ReportReason). Les libellés ci-dessous sont
/// ceux affichés dans l'app ; seule `apiValue` doit correspondre exactement
/// au nom de l'enum back, sous peine de 422 (motif non applicable).
enum ReportReason {
  harassment,
  fakeProfile,
  scamAttempt,
  prohibitedItem,
  falseInformation,
  inappropriateContent,
  spam,
  paymentIssue,
  appBug,
  other,
}

extension ReportReasonApi on ReportReason {
  String get apiValue => switch (this) {
    ReportReason.harassment => 'HARASSMENT',
    ReportReason.fakeProfile => 'FAKE_PROFILE',
    ReportReason.scamAttempt => 'SCAM_ATTEMPT',
    ReportReason.prohibitedItem => 'PROHIBITED_ITEM',
    ReportReason.falseInformation => 'FALSE_INFORMATION',
    ReportReason.inappropriateContent => 'INAPPROPRIATE_CONTENT',
    ReportReason.spam => 'SPAM',
    ReportReason.paymentIssue => 'PAYMENT_ISSUE',
    ReportReason.appBug => 'APP_BUG',
    ReportReason.other => 'OTHER',
  };

  String get label => switch (this) {
    ReportReason.harassment => 'Harcèlement ou comportement abusif',
    ReportReason.fakeProfile => 'Faux profil',
    ReportReason.scamAttempt => 'Tentative d\'arnaque',
    ReportReason.prohibitedItem => 'Objet interdit au transport',
    ReportReason.falseInformation => 'Informations fausses ou trompeuses',
    ReportReason.inappropriateContent => 'Contenu inapproprié',
    ReportReason.spam => 'Spam',
    ReportReason.paymentIssue => 'Problème de paiement',
    ReportReason.appBug => 'Bug de l\'application',
    ReportReason.other => 'Autre',
  };
}

/// Sous-ensemble catalogué applicable à chaque type de cible — doit rester
/// synchronisé avec `ReportReason.appliesTo` côté back.
List<ReportReason> reportReasonsFor(IncidentTargetType targetType) =>
    switch (targetType) {
      IncidentTargetType.user => const [
        ReportReason.harassment,
        ReportReason.fakeProfile,
        ReportReason.scamAttempt,
        ReportReason.inappropriateContent,
        ReportReason.other,
      ],
      IncidentTargetType.announcement => const [
        ReportReason.scamAttempt,
        ReportReason.prohibitedItem,
        ReportReason.falseInformation,
        ReportReason.inappropriateContent,
        ReportReason.other,
      ],
      IncidentTargetType.bid => const [
        ReportReason.scamAttempt,
        ReportReason.prohibitedItem,
        ReportReason.falseInformation,
        ReportReason.paymentIssue,
        ReportReason.other,
      ],
      IncidentTargetType.message => const [
        ReportReason.inappropriateContent,
        ReportReason.spam,
        ReportReason.other,
      ],
      IncidentTargetType.rating => const [
        ReportReason.inappropriateContent,
        ReportReason.spam,
        ReportReason.other,
      ],
      IncidentTargetType.app => const [
        ReportReason.paymentIssue,
        ReportReason.appBug,
        ReportReason.other,
      ],
    };
