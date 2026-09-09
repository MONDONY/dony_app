import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Miroir de `CurrencyPaymentRails` côté backend. Recette du 2026-09-09 : une
/// annonce XOF proposait la carte et le séquestre Stripe partait en euros.
void main() {
  group('BidPaymentMethodRails.isAllowedIn', () {
    test('zone CFA : espèces et mobile money, jamais la carte', () {
      for (final code in ['XOF', 'XAF', 'xof']) {
        expect(BidPaymentMethod.cash.isAllowedIn(code), isTrue, reason: code);
        expect(
          BidPaymentMethod.mobileMoney.isAllowedIn(code),
          isTrue,
          reason: code,
        );
        expect(
          BidPaymentMethod.stripe.isAllowedIn(code),
          isFalse,
          reason: code,
        );
      }
    });

    test('hors zone CFA : carte et espèces, jamais le mobile money', () {
      for (final code in ['EUR', 'USD', 'CAD', 'GBP', 'CHF']) {
        expect(BidPaymentMethod.cash.isAllowedIn(code), isTrue, reason: code);
        expect(BidPaymentMethod.stripe.isAllowedIn(code), isTrue, reason: code);
        expect(
          BidPaymentMethod.mobileMoney.isAllowedIn(code),
          isFalse,
          reason: code,
        );
      }
    });

    test('devise absente ou inconnue : repli euro, comme le backend', () {
      expect(BidPaymentMethod.stripe.isAllowedIn(null), isTrue);
      expect(BidPaymentMethod.mobileMoney.isAllowedIn(null), isFalse);
      expect(BidPaymentMethod.stripe.isAllowedIn('ZZZ'), isTrue);
      expect(BidPaymentMethod.mobileMoney.isAllowedIn('ZZZ'), isFalse);
    });

    test('rails retirés (Wave, Orange Money) : nulle part', () {
      for (final code in ['XOF', 'EUR']) {
        expect(BidPaymentMethod.wave.isAllowedIn(code), isFalse, reason: code);
        expect(
          BidPaymentMethod.orangeMoney.isAllowedIn(code),
          isFalse,
          reason: code,
        );
      }
    });
  });
}
