import 'package:dony/features/kyc/presentation/kyc_rejection_messages.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('kycRejectionMessage', () {
    test('document_expired — fr égal à l\'ancien message', () {
      expect(
        kycRejectionMessage(fr, 'document_expired'),
        "Votre pièce d'identité est expirée. Utilisez un document valide et "
        'réessayez.',
      );
    });
    test('document_expired — en', () {
      expect(
        kycRejectionMessage(en, 'document_expired'),
        'Your ID document has expired. Use a valid document and try again.',
      );
    });

    test('document_type_not_supported — fr égal à l\'ancien message', () {
      expect(
        kycRejectionMessage(fr, 'document_type_not_supported'),
        "Ce type de document n'est pas accepté. Utilisez une carte "
        "d'identité, un passeport ou un permis de conduire.",
      );
    });
    test('document_type_not_supported — en', () {
      expect(
        kycRejectionMessage(en, 'document_type_not_supported'),
        'This document type is not accepted. Use an ID card, a passport, '
        "or a driver's license.",
      );
    });

    test('document_unverified_other — fr égal à l\'ancien message', () {
      final message = kycRejectionMessage(fr, 'document_unverified_other');
      expect(message, contains('document fourni'));
    });
    test('document_unverified_other — en', () {
      expect(
        kycRejectionMessage(en, 'document_unverified_other'),
        'The document provided could not be read or verified. Make sure it '
        'is sharp, complete, and well lit, then try again.',
      );
    });

    test('country_not_supported — fr égal à l\'ancien message', () {
      expect(
        kycRejectionMessage(fr, 'country_not_supported'),
        "Le pays de votre document n'est pas pris en charge pour la "
        'vérification.',
      );
    });
    test('country_not_supported — en', () {
      expect(
        kycRejectionMessage(en, 'country_not_supported'),
        'Your document\'s country is not supported for verification.',
      );
    });

    test('id_number_insufficient_document_data / id_number_mismatch / '
        'id_number_unverified_other partagent le même message fr', () {
      const codes = [
        'id_number_insufficient_document_data',
        'id_number_mismatch',
        'id_number_unverified_other',
      ];
      for (final code in codes) {
        expect(
          kycRejectionMessage(fr, code),
          'Les informations de votre document n\'ont pas pu être '
          'confirmées. Vérifiez qu\'elles sont bien lisibles et '
          'réessayez.',
          reason: 'code=$code',
        );
      }
    });
    test('id_number_insufficient_document_data / id_number_mismatch / '
        'id_number_unverified_other partagent le même message en', () {
      const codes = [
        'id_number_insufficient_document_data',
        'id_number_mismatch',
        'id_number_unverified_other',
      ];
      for (final code in codes) {
        expect(
          kycRejectionMessage(en, code),
          'The information on your document could not be confirmed. '
          'Make sure it is clearly legible and try again.',
          reason: 'code=$code',
        );
      }
    });

    test('selfie_document_missing_photo — fr égal à l\'ancien message', () {
      expect(
        kycRejectionMessage(fr, 'selfie_document_missing_photo'),
        'La photo sur votre document n\'a pas pu être comparée à votre '
        'selfie. Réessayez avec une pièce d\'identité comportant une '
        'photo nette.',
      );
    });
    test('selfie_document_missing_photo — en', () {
      expect(
        kycRejectionMessage(en, 'selfie_document_missing_photo'),
        'The photo on your document could not be compared with your '
        'selfie. Try again with an ID document that has a clear photo.',
      );
    });

    test('selfie_face_mismatch — fr égal à l\'ancien message', () {
      expect(
        kycRejectionMessage(fr, 'selfie_face_mismatch'),
        'Votre selfie ne correspond pas à la photo du document. Reprenez '
        'la vérification dans de bonnes conditions de lumière.',
      );
    });
    test('selfie_face_mismatch — en', () {
      expect(
        kycRejectionMessage(en, 'selfie_face_mismatch'),
        'Your selfie does not match the photo on the document. Retry the '
        'verification in good lighting conditions.',
      );
    });

    test('selfie_manipulated / selfie_unverified_other partagent le même '
        'message fr', () {
      expect(
        kycRejectionMessage(fr, 'selfie_manipulated'),
        kycRejectionMessage(fr, 'selfie_unverified_other'),
      );
      expect(
        kycRejectionMessage(fr, 'selfie_manipulated'),
        'Votre selfie n\'a pas pu être vérifié. Réessayez dans un endroit '
        'bien éclairé, sans lunettes ni couvre-chef.',
      );
    });
    test('selfie_manipulated / selfie_unverified_other partagent le même '
        'message en', () {
      expect(
        kycRejectionMessage(en, 'selfie_manipulated'),
        'Your selfie could not be verified. Try again in a well-lit '
        'place, without glasses or headwear.',
      );
    });

    test('under_supported_age — fr égal à l\'ancien message', () {
      expect(
        kycRejectionMessage(fr, 'under_supported_age'),
        "La vérification d'identité est réservée aux personnes majeures.",
      );
    });
    test('under_supported_age — en', () {
      expect(
        kycRejectionMessage(en, 'under_supported_age'),
        'Identity verification is reserved for adults.',
      );
    });

    test('consent_declined — fr égal à l\'ancien message', () {
      final message = kycRejectionMessage(fr, 'consent_declined');
      expect(message, contains('consentement'));
    });
    test('consent_declined — en', () {
      expect(
        kycRejectionMessage(en, 'consent_declined'),
        'You declined to give your consent, which is required to verify '
        'your identity.',
      );
    });

    test('session_canceled — fr égal à l\'ancien message', () {
      expect(
        kycRejectionMessage(fr, 'session_canceled'),
        'La vérification a été fermée avant d\'être terminée.',
      );
    });
    test('session_canceled — en', () {
      expect(
        kycRejectionMessage(en, 'session_canceled'),
        'The verification was closed before it was completed.',
      );
    });

    test('code inconnu — fr tombe sur le message générique', () {
      final message = kycRejectionMessage(fr, 'some_future_stripe_code');
      expect(message, contains("Nous n'avons pas pu vérifier votre identité"));
    });
    test('code inconnu — en tombe sur le message générique', () {
      expect(
        kycRejectionMessage(en, 'some_future_stripe_code'),
        'We could not verify your identity. Make sure your document is '
        'legible and try again.',
      );
    });

    test('null — fr tombe sur le message générique', () {
      final message = kycRejectionMessage(fr, null);
      expect(message, contains("Nous n'avons pas pu vérifier votre identité"));
    });
    test('null — en tombe sur le message générique', () {
      expect(
        kycRejectionMessage(en, null),
        'We could not verify your identity. Make sure your document is '
        'legible and try again.',
      );
    });

    test(
      'every known code maps to a non-empty, distinct-from-generic message',
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
        final generic = kycRejectionMessage(fr, 'unknown');
        for (final code in codes) {
          final message = kycRejectionMessage(fr, code);
          expect(message, isNotEmpty, reason: 'code=$code');
          expect(message, isNot(equals(generic)), reason: 'code=$code');
        }
      },
    );
  });
}
