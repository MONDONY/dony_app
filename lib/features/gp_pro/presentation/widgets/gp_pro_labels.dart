import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellés traduits des valeurs GP Pro (fréquences, justificatifs, erreurs).
extension GpProLabels on AppLocalizations {
  String gpProFrequency(GpProFrequency frequency) => switch (frequency) {
    GpProFrequency.weekly => gpProFrequencyWeekly,
    GpProFrequency.twiceAMonth => gpProFrequencyTwiceAMonth,
    GpProFrequency.monthly => gpProFrequencyMonthly,
    GpProFrequency.lessOften => gpProFrequencyLessOften,
  };

  String gpProDocType(GpProDocType type) => switch (type) {
    GpProDocType.businessRegistration => gpProDocTypeBusinessRegistration,
    GpProDocType.travelProof => gpProDocTypeTravelProof,
    GpProDocType.socialProfile => gpProDocTypeSocialProfile,
    GpProDocType.other => gpProDocTypeOther,
  };

  /// Message d'une erreur du cubit, par famille : [code] est le code du back
  /// (`gp-pro-…`), `network` ou `unknown`.
  String gpProError(String code) => switch (code) {
    'network' => gpProErrorNetwork,
    'gp-pro-too-many-documents' => gpProErrorTooManyDocuments,
    'gp-pro-document-invalid' => gpProErrorDocumentInvalid,
    'gp-pro-document-storage-unavailable' => gpProErrorStorageUnavailable,
    'gp-pro-kyc-required' => gpProErrorKycRequired,
    _ => gpProErrorGeneric,
  };
}
