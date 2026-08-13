import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disputeTypeLabel traduit les types delivery no-show', () {
    expect(
      disputeTypeLabel('RECIPIENT_NO_SHOW_CONTESTED'),
      'Absence du destinataire',
    );
    expect(disputeTypeLabel('RECIPIENT_NO_SHOW'), 'Absence du destinataire');
    expect(
      disputeTypeLabel('TRAVELER_DELIVERY_NO_SHOW_CONTESTED'),
      'Défaut de livraison',
    );
    expect(
      disputeTypeLabel('TRAVELER_DELIVERY_NO_SHOW'),
      'Défaut de livraison',
    );
  });

  test(
    'disputeTypeLabel garde le comportement existant (contestation d\'absence + fallback)',
    () {
      expect(
        disputeTypeLabel('SENDER_NO_SHOW_CONTESTED'),
        "Contestation d'absence",
      );
      expect(disputeTypeLabel('UNKNOWN_TYPE'), 'UNKNOWN_TYPE');
    },
  );

  test('disputeStatusLabel traduit les statuts connus + fallback', () {
    expect(disputeStatusLabel('OPEN'), 'En instruction');
    expect(disputeStatusLabel('RESOLVED'), 'Résolu');
    expect(disputeStatusLabel('UNKNOWN_STATUS'), 'UNKNOWN_STATUS');
  });
}
