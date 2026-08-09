import 'package:dony/core/models/stripe_requirement_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripeRequirementLabel', () {
    test('maps external_account to IBAN message', () {
      expect(stripeRequirementLabel('external_account'), 'Ajoute ton IBAN');
    });

    test('maps identity document fields to document message', () {
      expect(
        stripeRequirementLabel('individual.verification.document'),
        "Envoie une pièce d'identité",
      );
      expect(
        stripeRequirementLabel('individual.verification.additional_document'),
        "Envoie une pièce d'identité",
      );
    });

    test('maps dob fields to date of birth message', () {
      expect(stripeRequirementLabel('individual.dob.day'), 'Renseigne ta date de naissance');
      expect(stripeRequirementLabel('individual.dob.month'), 'Renseigne ta date de naissance');
      expect(stripeRequirementLabel('individual.dob.year'), 'Renseigne ta date de naissance');
    });

    test('maps address fields to address message', () {
      expect(stripeRequirementLabel('individual.address.line1'), 'Renseigne ton adresse');
      expect(stripeRequirementLabel('individual.address.postal_code'), 'Renseigne ton adresse');
    });

    test('falls back to generic message for unmapped fields', () {
      expect(
        stripeRequirementLabel('some.unmapped.field'),
        'Complète les informations manquantes',
      );
    });
  });
}
