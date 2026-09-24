import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';
import 'package:dony/features/payments/wallet/presentation/commission_shortfall_text.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('commissionShortfallLines — égalité ligne à ligne', () {
    // Cas XOF/EUR partagé par les deux branches : une part du colis (XOF)
    // couvre une partie de la commission, le reste manque sur la devise
    // active (EUR).
    const coveredBreakdown = CommissionShortfall(
      bidCurrency: 'XOF',
      commission: 1050,
      coveredByBidWallet: 600,
      remainingBid: 450,
      remainingInActive: 0.69,
      activeCurrency: 'EUR',
      activeBalance: 1.33,
    );

    // Rien couvert par le portefeuille du colis : la commission entière est
    // convertie sur la devise active, insuffisante.
    const uncoveredBreakdown = CommissionShortfall(
      bidCurrency: 'XOF',
      commission: 1050,
      coveredByBidWallet: 0,
      remainingBid: 1050,
      remainingInActive: 1.60,
      activeCurrency: 'EUR',
      activeBalance: 1.33,
    );

    test('fr — part couverte : identique à l\'ancienne concaténation', () {
      final lines = commissionShortfallLines(
        fr,
        breakdown: coveredBreakdown,
        requiredCommission: 1.60,
        availableBalance: 1.33,
        currency: 'EUR',
      );

      final bidName = SupportedCurrency.xof.name(fr);
      final activeName = SupportedCurrency.eur.name(fr);
      final commissionBid = formatPriceIn(1050, 'XOF');
      final coveredBid = formatPriceIn(600, 'XOF');
      final remainingBid = formatPriceIn(450, 'XOF');
      final remainingActive = formatPriceIn(0.69, 'EUR');
      final activeBalance = formatPriceIn(1.33, 'EUR');

      expect(lines, [
        'Commission : $commissionBid',
        'Ton portefeuille $bidName en couvre $coveredBid',
        'Il manque $remainingBid, soit $remainingActive, et ton '
            'portefeuille $activeName n\'a que $activeBalance',
      ]);
    });

    test('fr — rien couvert : identique à l\'ancienne concaténation', () {
      final lines = commissionShortfallLines(
        fr,
        breakdown: uncoveredBreakdown,
        requiredCommission: 1.60,
        availableBalance: 1.33,
        currency: 'EUR',
      );

      final activeName = SupportedCurrency.eur.name(fr);
      final bidSymbol = SupportedCurrency.xof.symbol;
      final commissionBid = formatPriceIn(1050, 'XOF');
      final remainingActive = formatPriceIn(1.60, 'EUR');
      final activeBalance = formatPriceIn(1.33, 'EUR');

      expect(lines, [
        'Commission : $commissionBid, soit $remainingActive',
        'Ton portefeuille $activeName n\'a que $activeBalance. Recharge en '
            '$bidSymbol ou en $activeName, ou paie par carte.',
      ]);
    });

    test('fr — sans breakdown : identique à l\'ancienne concaténation', () {
      final lines = commissionShortfallLines(
        fr,
        breakdown: null,
        requiredCommission: 1.60,
        availableBalance: 1.33,
        currency: 'EUR',
      );

      expect(lines, [
        'Commission requise : ${formatPriceIn(1.60, 'EUR')}',
        'Solde du portefeuille : ${formatPriceIn(1.33, 'EUR')}',
      ]);
    });

    test('en — part couverte : gabarit anglais avec les mêmes montants', () {
      final lines = commissionShortfallLines(
        en,
        breakdown: coveredBreakdown,
        requiredCommission: 1.60,
        availableBalance: 1.33,
        currency: 'EUR',
      );

      final bidName = SupportedCurrency.xof.name(en);
      final activeName = SupportedCurrency.eur.name(en);
      final commissionBid = formatPriceIn(1050, 'XOF');
      final coveredBid = formatPriceIn(600, 'XOF');
      final remainingBid = formatPriceIn(450, 'XOF');
      final remainingActive = formatPriceIn(0.69, 'EUR');
      final activeBalance = formatPriceIn(1.33, 'EUR');

      expect(lines, [
        'Service fee: $commissionBid',
        'Your $bidName wallet covers $coveredBid',
        'You\'re short $remainingBid ($remainingActive), and your '
            '$activeName wallet only has $activeBalance',
      ]);
    });

    test('en — rien couvert : gabarit anglais avec les mêmes montants', () {
      final lines = commissionShortfallLines(
        en,
        breakdown: uncoveredBreakdown,
        requiredCommission: 1.60,
        availableBalance: 1.33,
        currency: 'EUR',
      );

      final activeName = SupportedCurrency.eur.name(en);
      final bidSymbol = SupportedCurrency.xof.symbol;
      final commissionBid = formatPriceIn(1050, 'XOF');
      final remainingActive = formatPriceIn(1.60, 'EUR');
      final activeBalance = formatPriceIn(1.33, 'EUR');

      expect(lines, [
        'Service fee: $commissionBid ($remainingActive)',
        'Your $activeName wallet only has $activeBalance. Top up in '
            '$bidSymbol or $activeName, or pay by card.',
      ]);
    });

    test('en — sans breakdown : gabarit anglais', () {
      final lines = commissionShortfallLines(
        en,
        breakdown: null,
        requiredCommission: 1.60,
        availableBalance: 1.33,
        currency: 'EUR',
      );

      expect(lines, [
        'Service fee due: ${formatPriceIn(1.60, 'EUR')}',
        'Wallet balance: ${formatPriceIn(1.33, 'EUR')}',
      ]);
    });
  });

  group('motifs de date du portefeuille', () {
    final d = DateTime(2026, 10, 6, 14, 5);

    test('walletDatePattern — fr égale l\'ancien motif "dd MMM yyyy"', () {
      expect(
        DateFormat(fr.walletDatePattern, fr.localeName).format(d),
        '06 oct. 2026',
      );
    });

    test('walletDatePattern — en', () {
      final rendered = DateFormat(
        en.walletDatePattern,
        en.localeName,
      ).format(d);
      expect(rendered, contains('Oct'));
      expect(rendered, contains('6'));
      expect(rendered, contains('2026'));
    });

    test(
      'walletTxDateTimePattern — fr égale l\'ancien motif "dd MMM · HH:mm"',
      () {
        expect(
          DateFormat(fr.walletTxDateTimePattern, fr.localeName).format(d),
          '06 oct. · 14:05',
        );
      },
    );

    test('walletTxDateTimePattern — en', () {
      final rendered = DateFormat(
        en.walletTxDateTimePattern,
        en.localeName,
      ).format(d);
      expect(rendered, contains('Oct 6'));
      expect(rendered, contains('2:05'));
      expect(rendered, contains('PM'));
    });

    test('walletTopupDateTimePattern — fr égale l\'ancien motif '
        '"dd MMM yyyy · HH:mm"', () {
      expect(
        DateFormat(fr.walletTopupDateTimePattern, fr.localeName).format(d),
        '06 oct. 2026 · 14:05',
      );
    });

    test('walletTopupDateTimePattern — en', () {
      final rendered = DateFormat(
        en.walletTopupDateTimePattern,
        en.localeName,
      ).format(d);
      expect(rendered, contains('Oct 6, 2026'));
      expect(rendered, contains('2:05'));
      expect(rendered, contains('PM'));
    });
  });

  group('variantes « Remboursable »', () {
    test('walletRefundable', () {
      expect(fr.walletRefundable('12,00 €'), 'Remboursable : 12,00 €');
      expect(en.walletRefundable('€12.00'), 'Refundable: €12.00');
    });

    test('walletRefundableOnMobileMoney', () {
      expect(
        fr.walletRefundableOnMobileMoney('12,00 €'),
        'Remboursable sur mobile money : 12,00 €',
      );
      expect(
        en.walletRefundableOnMobileMoney('€12.00'),
        'Refundable to mobile money: €12.00',
      );
    });

    test('walletRefundableOnCard', () {
      expect(
        fr.walletRefundableOnCard('12,00 €'),
        'Remboursable sur votre carte : 12,00 €',
      );
      expect(
        en.walletRefundableOnCard('€12.00'),
        'Refundable to your card: €12.00',
      );
    });
  });
}
