import 'package:dony/core/models/kyc_rejection_reason_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kycRejectionReasonLabel', () {
    test('maps document_expired to a specific message', () {
      expect(
        kycRejectionReasonLabel('document_expired'),
        contains('expiré'),
      );
    });

    test('maps document_type_not_supported to a specific message', () {
      expect(
        kycRejectionReasonLabel('document_type_not_supported'),
        contains('pas accepté'),
      );
    });

    test('maps selfie_document_mismatch to a specific message', () {
      expect(
        kycRejectionReasonLabel('selfie_document_mismatch'),
        contains('ne correspond pas'),
      );
    });

    test('maps selfie_manipulated and selfie_unverified_other identically', () {
      expect(
        kycRejectionReasonLabel('selfie_manipulated'),
        kycRejectionReasonLabel('selfie_unverified_other'),
      );
    });

    test('maps under_supported_age to a specific message', () {
      expect(
        kycRejectionReasonLabel('under_supported_age'),
        contains('majeures'),
      );
    });

    test('maps session_canceled to a specific message', () {
      expect(
        kycRejectionReasonLabel('session_canceled'),
        contains('annulée'),
      );
    });

    test('falls back to generic message for unmapped reason', () {
      expect(
        kycRejectionReasonLabel('some_unmapped_reason'),
        "Nous n'avons pas pu vérifier ton identité. Assure-toi que ton document est lisible et réessaie.",
      );
    });

    test('falls back to generic message for null reason', () {
      expect(
        kycRejectionReasonLabel(null),
        "Nous n'avons pas pu vérifier ton identité. Assure-toi que ton document est lisible et réessaie.",
      );
    });
  });
}
