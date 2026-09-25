import 'package:dony/l10n/l10n.dart';

/// Message affiché à l'utilisateur pour chaque code d'échec Stripe Identity /
/// Didit (`last_error.code` sur `identity.verification_session.requires_input`).
/// `null`/code inconnu → message générique en repli.
String kycRejectionMessage(AppLocalizations l, String? rejectionCode) {
  switch (rejectionCode) {
    case 'document_expired':
      return l.kycRejectionDocumentExpired;
    case 'document_type_not_supported':
      return l.kycRejectionDocumentTypeNotSupported;
    case 'document_unverified_other':
      return l.kycRejectionDocumentUnverifiedOther;
    case 'country_not_supported':
      return l.kycRejectionCountryNotSupported;
    case 'id_number_insufficient_document_data':
    case 'id_number_mismatch':
    case 'id_number_unverified_other':
      return l.kycRejectionIdNumberMismatch;
    case 'selfie_document_missing_photo':
      return l.kycRejectionSelfieDocumentMissingPhoto;
    case 'selfie_face_mismatch':
      return l.kycRejectionSelfieFaceMismatch;
    case 'selfie_manipulated':
    case 'selfie_unverified_other':
      return l.kycRejectionSelfieUnverified;
    case 'under_supported_age':
      return l.kycRejectionUnderSupportedAge;
    case 'consent_declined':
      return l.kycRejectionConsentDeclined;
    case 'session_canceled':
      return l.kycRejectionSessionCanceled;
    default:
      return l.kycRejectionGeneric;
  }
}
