import 'package:dony/features/package_request/data/models/negotiation_quote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NegotiationQuote.fromJson', () {
    test('parses a quote without promo', () {
      final quote = NegotiationQuote.fromJson({
        'netEur': 40.0,
        'rate': 0.05,
        'commissionEur': 2.0,
        'totalEur': 42.0,
        'promoApplied': false,
      });

      expect(quote.netEur, 40.0);
      expect(quote.rate, 0.05);
      expect(quote.commissionEur, 2.0);
      expect(quote.totalEur, 42.0);
      expect(quote.promoApplied, false);
      expect(quote.promoLabel, isNull);
    });

    test('parses a quote with an applied promo', () {
      final quote = NegotiationQuote.fromJson({
        'netEur': 40.0,
        'rate': 0.12,
        'commissionEur': 4.80,
        'totalEur': 42.40,
        'promoApplied': true,
        'promoLabel': 'Code WELCOME6 : 6 % de réduction',
      });

      expect(quote.promoApplied, true);
      expect(quote.promoLabel, 'Code WELCOME6 : 6 % de réduction');
    });

    test('promoApplied defaults to false when absent', () {
      final quote = NegotiationQuote.fromJson({
        'netEur': 40.0,
        'rate': 0.05,
        'commissionEur': 2.0,
        'totalEur': 42.0,
      });

      expect(quote.promoApplied, false);
    });

    test('accepts integer values from JSON (num → double)', () {
      final quote = NegotiationQuote.fromJson({
        'netEur': 40,
        'rate': 0,
        'commissionEur': 0,
        'totalEur': 40,
        'promoApplied': false,
      });

      expect(quote.netEur, 40.0);
      expect(quote.rate, 0.0);
    });
  });
}
