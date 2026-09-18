import 'package:dony/features/matching/data/models/commission_shortfall.dart';
import 'package:dony/features/payments/wallet/presentation/commission_shortfall_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sans breakdown : textes historiques', () {
    final lines = commissionShortfallLines(
      breakdown: null,
      requiredCommission: 1.60,
      availableBalance: 1.33,
      currency: 'EUR',
    );

    expect(lines, hasLength(2));
    expect(lines[0], startsWith('Commission requise : '));
    expect(lines[0], contains('1,60'));
    expect(lines[1], startsWith('Solde du portefeuille : '));
    expect(lines[1], contains('1,33'));
  });

  test('breakdown avec une part couverte par le portefeuille du colis', () {
    final lines = commissionShortfallLines(
      breakdown: const CommissionShortfall(
        bidCurrency: 'XOF',
        commission: 1050,
        coveredByBidWallet: 600,
        remainingBid: 450,
        remainingInActive: 0.69,
        activeCurrency: 'EUR',
        activeBalance: 1.33,
      ),
      requiredCommission: 1.60,
      availableBalance: 1.33,
      currency: 'EUR',
    );

    expect(lines, hasLength(3));
    expect(lines[0], startsWith('Commission : '));
    expect(lines[0], contains('1'));
    expect(lines[1], contains('Ton portefeuille Franc CFA Ouest en couvre'));
    expect(lines[1], contains('600'));
    expect(lines[2], contains('Il manque'));
    expect(lines[2], contains('450'));
    expect(lines[2], contains('0,69'));
    expect(lines[2], contains('ton portefeuille Euro n\'a que'));
    expect(lines[2], contains('1,33'));
  });

  test('breakdown sans rien sur le portefeuille du colis', () {
    final lines = commissionShortfallLines(
      breakdown: const CommissionShortfall(
        bidCurrency: 'XOF',
        commission: 1050,
        coveredByBidWallet: 0,
        remainingBid: 1050,
        remainingInActive: 1.60,
        activeCurrency: 'EUR',
        activeBalance: 1.33,
      ),
      requiredCommission: 1.60,
      availableBalance: 1.33,
      currency: 'EUR',
    );

    expect(lines, hasLength(2));
    expect(lines[0], startsWith('Commission : '));
    expect(lines[0], contains('soit'));
    expect(lines[0], contains('1,60'));
    expect(lines[1], contains('Ton portefeuille Euro n\'a que'));
    expect(
      lines[1],
      contains('Recharge en F CFA ou en Euro, ou paie par carte.'),
    );
  });

  test('aucun tiret cadratin dans les textes', () {
    final lines = commissionShortfallLines(
      breakdown: const CommissionShortfall(
        bidCurrency: 'XOF',
        commission: 1050,
        coveredByBidWallet: 600,
        remainingBid: 450,
        remainingInActive: 0.69,
        activeCurrency: 'EUR',
        activeBalance: 1.33,
      ),
      requiredCommission: 1.60,
      availableBalance: 1.33,
      currency: 'EUR',
    );
    for (final l in lines) {
      expect(l.contains('—'), isFalse);
    }
  });
}
