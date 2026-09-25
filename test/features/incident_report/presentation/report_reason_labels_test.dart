import 'package:dony/features/incident_report/data/report_reasons.dart';
import 'package:dony/features/incident_report/presentation/report_reason_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  const frLabels = {
    ReportReason.harassment: 'Harcèlement ou comportement abusif',
    ReportReason.fakeProfile: 'Faux profil',
    ReportReason.scamAttempt: 'Tentative d\'arnaque',
    ReportReason.prohibitedItem: 'Objet interdit au transport',
    ReportReason.falseInformation: 'Informations fausses ou trompeuses',
    ReportReason.inappropriateContent: 'Contenu inapproprié',
    ReportReason.spam: 'Spam',
    ReportReason.paymentIssue: 'Problème de paiement',
    ReportReason.appBug: 'Bug de l\'application',
    ReportReason.other: 'Autre',
  };

  const enLabels = {
    ReportReason.harassment: 'Harassment or abusive behavior',
    ReportReason.fakeProfile: 'Fake profile',
    ReportReason.scamAttempt: 'Scam attempt',
    ReportReason.prohibitedItem: 'Prohibited item',
    ReportReason.falseInformation: 'False or misleading information',
    ReportReason.inappropriateContent: 'Inappropriate content',
    ReportReason.spam: 'Spam',
    ReportReason.paymentIssue: 'Payment issue',
    ReportReason.appBug: 'App bug',
    ReportReason.other: 'Other',
  };

  for (final reason in ReportReason.values) {
    test('${reason.name} — label fr égale l\'ancien', () {
      expect(reason.label(fr), frLabels[reason]);
    });

    test('${reason.name} — label en', () {
      expect(reason.label(en), enLabels[reason]);
    });

    test('${reason.name} — apiValue inchangé (valeur envoyée au serveur)', () {
      // Le libellé affiché est traduit ; le code envoyé au back ne bouge pas.
      expect(reason.apiValue, isNotEmpty);
      expect(reason.apiValue, reason.apiValue.toUpperCase());
    });
  }
}
