import 'package:dony/features/kyc/presentation/kyc_rejection_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kycRejectionMessage', () {
    test('returns a specific message for a known code', () {
      final message = kycRejectionMessage('document_unverified_other');
      expect(message, contains('document fourni'));
    });

    test('returns a specific message for consent_declined', () {
      final message = kycRejectionMessage('consent_declined');
      expect(message, contains('consentement'));
    });

    test('falls back to a generic message for an unknown code', () {
      final message = kycRejectionMessage('some_future_stripe_code');
      expect(message, contains("Nous n'avons pas pu vérifier votre identité"));
    });

    test('falls back to a generic message for null', () {
      final message = kycRejectionMessage(null);
      expect(message, contains("Nous n'avons pas pu vérifier votre identité"));
    });

    test('every known code maps to a non-empty, distinct-from-generic message',
        () {
      const codes = [
        'document_expired',
        'document_type_not_supported',
        'document_unverified_other',
        'country_not_supported',
        'id_number_insufficient_document_data',
        'id_number_mismatch',
        'id_number_unverified_other',
        'selfie_document_missing_photo',
        'selfie_face_mismatch',
        'selfie_manipulated',
        'selfie_unverified_other',
        'under_supported_age',
        'consent_declined',
        'session_canceled',
      ];
      final generic = kycRejectionMessage('unknown');
      for (final code in codes) {
        final message = kycRejectionMessage(code);
        expect(message, isNotEmpty, reason: 'code=$code');
        expect(message, isNot(equals(generic)), reason: 'code=$code');
      }
    });
  });
}
