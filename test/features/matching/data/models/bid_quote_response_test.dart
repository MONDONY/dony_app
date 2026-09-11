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
  });
}
