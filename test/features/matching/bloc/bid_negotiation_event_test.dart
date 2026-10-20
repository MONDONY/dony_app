// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

BidNegotiationProposeRequested _propose({
  double? weightKg = 4,
  double total = 60,
  BidPaymentMethod method = BidPaymentMethod.stripe,
  List<Map<String, dynamic>>? gridItems,
}) => BidNegotiationProposeRequested(
  announcementId: 'a-1',
  weightKg: weightKg,
  description: 'Vêtements',
  contentCategory: 'CLOTHES',
  recipientName: 'Awa',
  recipientPhone: '+221770000000',
  proposedTotalEur: total,
  paymentMethod: method,
  countryCode: 'SN',
  photoKeys: const ['p1'],
  customItems: const [],
  gridItems: gridItems,
);

void main() {
  group('BidNegotiationEvent — égalité de valeur', () {
    test('chargement et ouverture : identifiant porté', () {
      expectValueEquality(() => BidNegotiationFetchRequested('b-1'), [
        BidNegotiationFetchRequested('b-2'),
        BidNegotiationAcceptRequested('b-1'),
      ]);
      expectValueEquality(() => BidNegotiationOpenRequested('a-1'), [
        BidNegotiationOpenRequested('a-2'),
      ]);
    });

    test('proposition : tous les champs participent à l’égalité', () {
      expectValueEquality(_propose, [
        _propose(weightKg: null),
        _propose(total: 61),
        _propose(method: BidPaymentMethod.cash),
        _propose(
          gridItems: const [
            {'id': 'g1', 'qty': 2},
          ],
        ),
      ]);
    });

    test('contre-offre : montant et message', () {
      expectValueEquality(
        () => BidNegotiationCounterRequested('b-1', proposedTotalEur: 50),
        [
          BidNegotiationCounterRequested('b-1', proposedTotalEur: 55),
          BidNegotiationCounterRequested(
            'b-1',
            proposedTotalEur: 50,
            body: 'Dernier prix',
          ),
        ],
      );
    });

    test('décisions sur une offre : identifiant et type distinguent', () {
      expectValueEquality(() => BidNegotiationAcceptRequested('b-1'), [
        BidNegotiationAcceptRequested('b-2'),
        BidNegotiationRejectRequested('b-1'),
      ]);
      expectValueEquality(() => BidNegotiationRejectRequested('b-1'), [
        BidNegotiationCancelRequested('b-1'),
      ]);
      expectValueEquality(() => BidNegotiationCancelRequested('b-1'), [
        BidNegotiationCancelRequested('b-2'),
      ]);
      expectValueEquality(() => BidNegotiationReadRequested('b-1'), [
        BidNegotiationReadRequested('b-2'),
      ]);
      expectValueEquality(() => BidNegotiationCheckoutRequested('b-1'), [
        BidNegotiationCheckoutRequested('b-2'),
        BidNegotiationReadRequested('b-1'),
      ]);
    });
  });
}
