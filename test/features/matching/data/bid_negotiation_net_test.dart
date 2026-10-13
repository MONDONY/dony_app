import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/models/bid_negotiation_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _thread({
  String role = 'TRAVELER',
  Object? commissionRate = 0.12,
}) => {
  'bidId': 'bid-1',
  'announcementId': 'ann-1',
  'status': 'NEGOTIATING',
  'role': role,
  'proposedGrossEur': 42.0,
  'netEur': 37.5,
  'commissionRate': ?commissionRate,
  'messages': [
    {
      'id': 'm1',
      'kind': 'PROPOSAL',
      'authorId': 's-1',
      'proposedGrossEur': 42.0,
      'proposedNetEur': 37.5,
    },
  ],
};

void main() {
  group('grossForNet (miroir de BidNegotiationPricing.grossForNet)', () {
    test('euro : 35 net à 12 % → 39,20', () {
      expect(grossForNet(35, 0.12, 'EUR'), 39.20);
    });

    test('euro : arrondi supérieur au centime, sans pas de trop', () {
      // 33,33 × 1,12 = 37,3296 → 37,33 ; 37,32 / 1,12 = 33,32 < 33,33.
      expect(grossForNet(33.33, 0.12, 'EUR'), 37.33);
    });

    test('euro : un pas de moins quand le net reste atteint', () {
      // 10,01 × 1,12 = 11,2112 → 11,22 ; 11,21 / 1,12 = 10,0089 → 10,01.
      expect(grossForNet(10.01, 0.12, 'EUR'), 11.21);
    });

    test('franc CFA : entier, au franc supérieur', () {
      expect(grossForNet(10000, 0.12, 'XOF'), 11200);
      // 1001 × 1,12 = 1121,12 → 1122 ; 1121 / 1,12 = 1000,89 < 1001.
      expect(grossForNet(1001, 0.12, 'XOF'), 1122);
    });

    test('taux nul : brut = net', () {
      expect(grossForNet(20, 0, 'EUR'), 20);
    });

    test('net nul ou négatif : 0', () {
      expect(grossForNet(0, 0.12, 'EUR'), 0);
    });
  });

  group('contrat FLUTTER-NS', () {
    test('voyageur : net par message et taux du fil', () {
      final t = BidNegotiation.fromJson(_thread());
      expect(t.commissionRate, 0.12);
      expect(t.messages.single.proposedNetEur, 37.5);
      expect(t.counterInNet, isTrue);
    });

    test('taux absent (ancien back) : saisie brute', () {
      final t = BidNegotiation.fromJson(_thread(commissionRate: null));
      expect(t.commissionRate, isNull);
      expect(t.counterInNet, isFalse);
    });

    test('expéditeur : jamais en net', () {
      final t = BidNegotiation.fromJson(_thread(role: 'SENDER'));
      expect(t.counterInNet, isFalse);
    });

    test('ligne de liste : net pour le voyageur, brut sinon', () {
      Map<String, dynamic> row(String role, {double? net}) => {
        'bidId': 'b',
        'announcementId': 'a',
        'status': 'NEGOTIATING',
        'role': role,
        'proposedGrossEur': 42.0,
        'proposedNetEur': ?net,
      };
      expect(
        BidNegotiationSummary.fromJson(
          row('TRAVELER', net: 37.5),
        ).displayAmount,
        37.5,
      );
      expect(BidNegotiationSummary.fromJson(row('TRAVELER')).displayAmount, 42);
      expect(
        BidNegotiationSummary.fromJson(row('SENDER', net: 37.5)).displayAmount,
        42,
      );
    });
  });
}
