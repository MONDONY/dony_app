import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BidQuoteResponse.fromJson', () {
    const base = <String, Object?>{
      'netEur': 60.0,
      'gridNetEur': 0,
      'kgNetEur': 60.0,
      'rate': 0.12,
      'commissionEur': 7.2,
      'totalEur': 67.2,
      'promoApplied': false,
      'promoLabel': null,
    };

    test('lit la devise déclarée par le backend', () {
      final quote = BidQuoteResponse.fromJson({...base, 'currency': 'XOF'});
      expect(quote.currency, 'XOF');
      expect(quote.totalEur, 67.2);
    });

    test('lit volumeNetEur (trajet au m³), 0 sur un back antérieur', () {
      final boat = BidQuoteResponse.fromJson({
        ...base,
        'kgNetEur': 0.0,
        'volumeNetEur': 60.0,
      });
      expect(boat.volumeNetEur, 60.0);
      expect(boat.kgNetEur, 0.0);
      expect(boat.toJson()['volumeNetEur'], 60.0);
      expect(BidQuoteResponse.fromJson(base).volumeNetEur, 0.0);
    });

    test('tolère un backend antérieur au champ currency', () {
      final quote = BidQuoteResponse.fromJson(base);
      expect(quote.currency, isNull);
    });

    test('sérialise la devise', () {
      const quote = BidQuoteResponse(
        netEur: 60.0,
        rate: 0.12,
        commissionEur: 7.2,
        totalEur: 67.2,
        promoApplied: false,
        currency: 'CAD',
      );
      expect(quote.toJson()['currency'], 'CAD');
    });

    test('lit minimumApplied, minimumAmount, commissionGridId, '
        'promoIneffectiveReason', () {
      final quote = BidQuoteResponse.fromJson({
        ...base,
        'currency': 'XOF',
        'minimumApplied': true,
        'minimumAmount': 650,
        'commissionGridId': 'grid-1',
        'promoIneffectiveReason': 'COMMISSION_MINIMUM',
      });
      expect(quote.minimumApplied, isTrue);
      expect(quote.minimumAmount, 650.0);
      expect(quote.commissionGridId, 'grid-1');
      expect(quote.promoIneffectiveReason, 'COMMISSION_MINIMUM');
      expect(quote.promoIneffectiveBecauseMinimum, isTrue);
    });

    test('ancien contrat sans ces champs : minimumApplied faux, le reste '
        'null', () {
      final quote = BidQuoteResponse.fromJson(base);
      expect(quote.minimumApplied, isFalse);
      expect(quote.minimumAmount, isNull);
      expect(quote.commissionGridId, isNull);
      expect(quote.promoIneffectiveReason, isNull);
      expect(quote.promoIneffectiveBecauseMinimum, isFalse);
    });
  });
}
