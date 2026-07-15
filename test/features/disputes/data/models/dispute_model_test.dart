import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson mappe tous les champs', () {
    final m = DisputeModel.fromJson({
      'id': 'd1',
      'bidId': 'b1',
      'type': 'SENDER_NO_SHOW_CONTESTED',
      'status': 'RESOLVED',
      'refundFrozen': false,
      'createdAt': '2026-06-02T10:00:00',
      'myRole': 'SENDER',
      'otherPartyName': 'Awa K.',
      'departureCity': 'Lyon',
      'arrivalCity': 'Abidjan',
      'departureCountryCode': 'FR',
      'arrivalCountryCode': 'CI',
      'tripDate': '2026-06-20',
      'weightKg': 5.0,
      'resolutionType': 'GUARANTEE_PAID',
      'resolvedAt': '2026-06-04T09:00:00Z',
      'resolutionNote': 'No-show confirmé.',
      'guaranteeAmountCents': 4000,
      'isBeneficiary': true,
    });
    expect(m.id, 'd1');
    expect(m.isResolved, isTrue);
    expect(m.isOpen, isFalse);
    expect(m.myRole, 'SENDER');
    expect(m.weightKg, 5.0);
    expect(m.guaranteeAmountCents, 4000);
    expect(m.isBeneficiary, isTrue);
    expect(m.tripDate, DateTime(2026, 6, 20));
  });

  test('fromJson tolère le contexte null (envoi supprimé)', () {
    final m = DisputeModel.fromJson({
      'id': 'd2',
      'bidId': null,
      'type': 'SENDER_NO_SHOW_CONTESTED',
      'status': 'OPEN',
      'refundFrozen': true,
      'createdAt': '2026-07-12T08:00:00',
      'myRole': 'TRAVELER',
      'otherPartyName': null,
      'departureCity': null,
      'arrivalCity': null,
      'departureCountryCode': null,
      'arrivalCountryCode': null,
      'tripDate': null,
      'weightKg': null,
      'resolutionType': null,
      'resolvedAt': null,
      'resolutionNote': null,
      'guaranteeAmountCents': null,
      'isBeneficiary': false,
    });
    expect(m.isOpen, isTrue);
    expect(m.departureCity, isNull);
    expect(m.weightKg, isNull);
    expect(m.resolvedAt, isNull);
  });
}
