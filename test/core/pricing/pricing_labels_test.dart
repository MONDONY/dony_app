import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('commissionPercentLabel', () {
    tearDown(() => setDonyCommissionRate(kDonyCommissionRateDefault));

    test('taux entier → entier sans décimale, fr et en identiques', () {
      setDonyCommissionRate(0.12);
      expect(commissionPercentLabel(fr), '12');
      expect(commissionPercentLabel(en), '12');
    });

    test('taux décimal → une décimale à la langue', () {
      setDonyCommissionRate(0.125);
      expect(commissionPercentLabel(fr), '12,5');
      expect(commissionPercentLabel(en), '12.5');
    });
  });

  group('reimbursementCapLabel', () {
    tearDown(() => setDonyReimbursementCap(kDonyReimbursementCapDefault));

    test('plafond entier → entier sans décimale, fr et en identiques', () {
      setDonyReimbursementCap(200);
      expect(reimbursementCapLabel(fr), '200');
      expect(reimbursementCapLabel(en), '200');
    });

    test('plafond décimal → décimales à la langue, sans zéro final', () {
      setDonyReimbursementCap(150.5);
      expect(reimbursementCapLabel(fr), '150,5');
      expect(reimbursementCapLabel(en), '150.5');
    });
  });
}
